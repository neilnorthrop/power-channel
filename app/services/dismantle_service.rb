# frozen_string_literal: true
require 'set'

class DismantleService
  DEFAULT_QUALITY = "normal"

  def initialize(user)
    @user = user
  end

  # Dismantle exactly one unit of the given item (by id) at a given quality.
  # Returns { success:, message: } or { success: false, error: }
  # Example return values:
  # { success: true, message: "Item dismantled successfully." }
  # { success: false, error: "Item not found in inventory." }
  # { success: false, error: "This item cannot be dismantled." }
  # { success: false, error: "No dismantle yields defined." }
  # { success: false, error: "No salvageable output." }
  # @param item_id [Integer] the ID of the item to dismantle
  # @param quality [String] the quality of the item to dismantle (default: 'normal')
  # @return [Hash] result of the dismantle attempt with success status and message or error details
  def dismantle_item(item_id, quality: DEFAULT_QUALITY)
    item = Item.find(item_id)
    user_item = @user.user_items.find_by(item_id: item.id, quality: quality)
    return { success: false, error: "Item not found in inventory." } unless user_item && user_item.quantity.to_i >= 1

    rule = DismantleRule.find_by(subject_type: "Item", subject_id: item.id)
    return { success: false, error: "This item cannot be dismantled." } unless rule

    yields = rule.dismantle_yields.to_a
    return { success: false, error: "No dismantle yields defined." } if yields.empty?

    # Precompute deterministic amounts
    computed = yields.map do |dy|
      amount = (dy.quantity.to_i * dy.salvage_rate.to_f).floor
      next if amount <= 0
      { type: dy.component_type, id: dy.component_id, amount: amount, quality: (dy.quality || DEFAULT_QUALITY) }
    end.compact
    return { success: false, error: "No salvageable output." } if computed.empty?

    # Preload user state for relevant IDs/qualities to reduce queries
    resource_ids = computed.select { |c| c[:type] == 'Resource' }.map { |c| c[:id] }.uniq
    item_ids     = (computed.select { |c| c[:type] == 'Item' }.map { |c| c[:id] } + [ item.id ]).uniq
    qualities    = (computed.select { |c| c[:type] == 'Item' }.map { |c| c[:quality] } + [ quality, DEFAULT_QUALITY ]).uniq
    user_resources_by_id = resource_ids.any? ? @user.user_resources.where(resource_id: resource_ids).index_by(&:resource_id) : {}
    user_items_by_key    = if item_ids.any?
      @user.user_items.where(item_id: item_ids, quality: qualities).index_by { |ui| [ ui.item_id, ui.quality ] }
    else
      {}
    end

    # Ensure the subject user_item is present in the local map
    user_items_by_key[[item.id, quality]] ||= user_item

    changed_resource_ids = Set.new
    changed_item_keys    = Set.new

    ApplicationRecord.transaction do
      # Decrement the dismantled item (specific quality)
      subj = user_items_by_key[[item.id, quality]]
      subj.decrement!(:quantity, 1)
      if subj.reload.quantity.to_i <= 0
        subj.destroy!
        user_items_by_key.delete([item.id, quality])
      end
      changed_item_keys << [item.id, quality]

      # Apply outputs
      computed.each do |out|
        case out[:type]
        when "Resource"
          ur = user_resources_by_id[out[:id]]
          unless ur
            ur = @user.user_resources.create!(resource_id: out[:id], amount: 0)
            user_resources_by_id[out[:id]] = ur
          end
          ur.update!(amount: ur.amount.to_i + out[:amount])
          changed_resource_ids << out[:id]
        when "Item"
          key = [ out[:id], out[:quality] ]
          ui = user_items_by_key[key]
          unless ui
            ui = @user.user_items.create!(item_id: out[:id], quality: out[:quality], quantity: 0)
            user_items_by_key[key] = ui
          end
          ui.update!(quantity: ui.quantity.to_i + out[:amount])
          changed_item_keys << key
        end
      end

      # Optionally evaluate flags here, if dismantling can unlock content
      # EnsureFlagsService.evaluate_for(@user, touch: { items: [item.id] })
    end

    # Broadcast delta updates using tracked changed sets
    res_changes = changed_resource_ids.map do |rid|
      ur = user_resources_by_id[rid] || @user.user_resources.find_by(resource_id: rid)
      { resource_id: rid, amount: ur&.amount.to_i }
    end
    # Preserve existing behavior: broadcast default-quality counts for all affected item_ids
    item_ids_for_broadcast = (changed_item_keys.map(&:first)).uniq
    item_changes = item_ids_for_broadcast.map do |iid|
      ui = user_items_by_key[[iid, DEFAULT_QUALITY]] || @user.user_items.find_by(item_id: iid, quality: DEFAULT_QUALITY)
      { item_id: iid, quality: DEFAULT_QUALITY, quantity: ui&.quantity.to_i }
    end
    UserUpdatesChannel.broadcast_to(@user, { type: 'user_resource_delta', data: { changes: res_changes } }) if res_changes.any?
    UserUpdatesChannel.broadcast_to(@user, { type: 'user_item_delta', data: { changes: item_changes } }) if item_changes.any?
    Event.create!(user: @user, level: "info", message: "Dismantled item: #{item.name}")
    { success: true, message: "#{item.name} dismantled successfully." }
  end
end
