# frozen_string_literal: true
require 'set'

class CraftingService
  DEFAULT_QUALITY = "normal"

  def initialize(user)
    @user = user
  end

  # Craft an item based on a recipe, checking for required resources and items
  # Returns a hash with success status and message or error details for the crafting attempt
  #
  # Example return values:
  # { success: true, message: "1 Item crafted!", hint: { kind: 'craft' } }
  # { success: false, error: "Not enough resources." }
  #
  # @param recipe_id [Integer] the ID of the recipe to craft
  # @return [Hash] result of the crafting attempt with success status and message or error details
  def craft_item(recipe_id)
    recipe = Recipe.find(recipe_id)
    reqs = recipe.recipe_resources.to_a

    # Preload user state for relevant component ids
    resource_ids = reqs.select { |rr| rr.component_type == "Resource" }.map(&:component_id)
    item_ids     = reqs.select { |rr| rr.component_type == "Item" }.map(&:component_id)
    # Include the crafted output item so we can update existing row instead of creating duplicates
    item_ids << recipe.item_id
    item_ids.uniq!
    user_resources_by_id = resource_ids.any? ? @user.user_resources.where(resource_id: resource_ids).index_by(&:resource_id) : {}
    user_items_by_id     = item_ids.any?     ? @user.user_items.where(item_id: item_ids, quality: DEFAULT_QUALITY).index_by(&:item_id) : {}

    changed_resource_ids = Set.new
    changed_item_ids     = Set.new

    # Verify availability with OR/AND groups
    selected = []
    grouped = reqs.group_by { |rr| rr.group_key.presence }

    can_craft = grouped.all? do |group_key, parts|
      if group_key.nil?
        parts.all? do |rr|
          case rr.component_type
          when "Resource"
            ur = user_resources_by_id[rr.component_id]
            ok = ur && ur.amount.to_i >= rr.quantity
            selected << rr if ok
            ok
          when "Item"
            ui = user_items_by_id[rr.component_id]
            ok = ui && ui.quantity.to_i >= rr.quantity
            selected << rr if ok
            ok
          else
            false
          end
        end
      else
        has_or = parts.any? { |rr| rr.logic.to_s.upcase == 'OR' }
        if has_or
          choice = parts.find do |rr|
            case rr.component_type
            when "Resource"
              ur = user_resources_by_id[rr.component_id]
              ur && ur.amount.to_i >= rr.quantity
            when "Item"
              ui = user_items_by_id[rr.component_id]
              ui && ui.quantity.to_i >= rr.quantity
            else
              false
            end
          end
          if choice
            selected << choice
            true
          else
            false
          end
        else
          parts.all? do |rr|
            case rr.component_type
            when "Resource"
              ur = user_resources_by_id[rr.component_id]
              ok = ur && ur.amount.to_i >= rr.quantity
              selected << rr if ok
              ok
            when "Item"
              ui = user_items_by_id[rr.component_id]
              ok = ui && ui.quantity.to_i >= rr.quantity
              selected << rr if ok
              ok
            else
              false
            end
          end
        end
      end
    end

    if can_craft
      # Perform the entire craft atomically
      ApplicationRecord.transaction do
        selected.each do |rr|
          case rr.component_type
          when "Resource"
            if (ur = user_resources_by_id[rr.component_id])
              ur.decrement!(:amount, rr.quantity)
              changed_resource_ids << rr.component_id
            end
          when "Item"
            if (ui = user_items_by_id[rr.component_id])
              ui.decrement!(:quantity, rr.quantity)
              changed_item_ids << rr.component_id
            end
          end
        end

        # Award crafted item using preload map (create only if needed)
        crafted = user_items_by_id[recipe.item_id]
        if crafted
          crafted.update!(quantity: crafted.quantity.to_i + 1)
        else
          crafted = @user.user_items.create!(item_id: recipe.item_id, quality: DEFAULT_QUALITY, quantity: 1)
          user_items_by_id[recipe.item_id] = crafted
        end
        changed_item_ids << recipe.item_id

        # Evaluate flags potentially satisfied by crafting this item within the transaction
        EnsureFlagsService.evaluate_for(@user, touch: { items: [ recipe.item_id ] })

        # Equip-style items: consume the crafted item after awarding the flag
        # Data-driven via flags: any flag with slug in the set below and requiring this item
        equippable_flag_slugs = %w[has_small_backpack has_basic_hatchet has_basic_pick has_spear]
        if Flag.joins(:flag_requirements).where(slug: equippable_flag_slugs, flag_requirements: { requirement_type: 'Item', requirement_id: recipe.item_id }).exists?
          # remove one crafted item so it does not remain in inventory
          crafted.reload
          if crafted.quantity.to_i > 0
            if crafted.quantity == 1
              crafted.destroy!
              user_items_by_id.delete(recipe.item_id)
            else
              crafted.decrement!(:quantity, 1)
            end
            changed_item_ids << recipe.item_id
          end
        end
      end

      # Broadcast deltas after commit so clients see committed state
      res_changes = changed_resource_ids.map do |rid|
        ur = user_resources_by_id[rid] || @user.user_resources.find_by(resource_id: rid)
        { resource_id: rid, amount: ur&.amount.to_i }
      end
      item_changes = changed_item_ids.map do |iid|
        ui = user_items_by_id[iid] || @user.user_items.find_by(item_id: iid, quality: DEFAULT_QUALITY)
        { item_id: iid, quality: DEFAULT_QUALITY, quantity: ui&.quantity.to_i }
      end
      UserUpdatesChannel.broadcast_to(@user, { type: 'user_resource_delta', data: { changes: res_changes } }) if res_changes.any?
      UserUpdatesChannel.broadcast_to(@user, { type: 'user_item_delta', data: { changes: item_changes } }) if item_changes.any?
      Event.create!(user: @user, level: "info", message: "Crafted item: #{recipe.item.name}")
      { success: true, message: "1 #{recipe.item.name} crafted!", hint: { kind: "craft" } }
    else
      Event.create!(user: @user, level: "warning", message: "Failed to craft (insufficient resources): #{recipe.item.name}")
      { success: false, error: "Not enough resources." }
    end
  end
end
