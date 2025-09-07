# frozen_string_literal: true

class DismantleService
  DEFAULT_QUALITY = 'normal'

  def initialize(user)
    @user = user
  end

  # Dismantle exactly one unit of the given item (by id) at a given quality.
  # Returns { success:, message: } or { success: false, error: }
  def dismantle_item(item_id, quality: DEFAULT_QUALITY)
    item = Item.find(item_id)
    user_item = @user.user_items.find_by(item_id: item.id, quality: quality)
    return { success: false, error: 'Item not found in inventory.' } unless user_item && user_item.quantity.to_i >= 1

    rule = DismantleRule.find_by(subject_type: 'Item', subject_id: item.id)
    return { success: false, error: 'This item cannot be dismantled.' } unless rule

    yields = rule.dismantle_yields.to_a
    return { success: false, error: 'No dismantle yields defined.' } if yields.empty?

    # Precompute deterministic amounts
    computed = yields.map do |dy|
      amount = (dy.quantity.to_i * dy.salvage_rate.to_f).floor
      next if amount <= 0
      { type: dy.component_type, id: dy.component_id, amount: amount, quality: (dy.quality || DEFAULT_QUALITY) }
    end.compact
    return { success: false, error: 'No salvageable output.' } if computed.empty?

    ApplicationRecord.transaction do
      user_item.decrement!(:quantity, 1)
      if user_item.reload.quantity.to_i <= 0
        user_item.destroy!
      end

      # Apply outputs
      computed.each do |out|
        case out[:type]
        when 'Resource'
          ur = @user.user_resources.find_or_initialize_by(resource_id: out[:id])
          ur.amount = ur.amount.to_i + out[:amount]
          ur.save!
        when 'Item'
          ui = @user.user_items.find_or_initialize_by(item_id: out[:id], quality: out[:quality])
          ui.quantity = ui.quantity.to_i + out[:amount]
          ui.save!
        end
      end

      # Optionally evaluate flags here, if dismantling can unlock content
      # EnsureFlagsService.evaluate_for(@user, touch: { items: [item.id] })
    end

    # Broadcast updates
    user_items = @user.user_items.includes(:item)
    item_ids = user_items.map(&:item_id).uniq
    items_with_effects = Effect.where(effectable_type: 'Item', effectable_id: item_ids).distinct.pluck(:effectable_id).to_set
    UserUpdatesChannel.broadcast_to(@user, { type: 'user_resource_update', data: UserResourcesSerializer.new(@user.user_resources.includes(:resource)).serializable_hash })
    UserUpdatesChannel.broadcast_to(@user, { type: 'user_item_update', data: UserItemSerializer.new(user_items, { params: { items_with_effects: items_with_effects } }).serializable_hash })
    Event.create!(user: @user, level: 'info', message: "Dismantled item: #{item.name}")
    { success: true, message: "#{item.name} dismantled successfully." }
  end
end
