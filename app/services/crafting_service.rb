# frozen_string_literal: true

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
    user_resources_by_id = resource_ids.any? ? @user.user_resources.where(resource_id: resource_ids).index_by(&:resource_id) : {}
    user_items_by_id     = item_ids.any?     ? @user.user_items.where(item_id: item_ids, quality: DEFAULT_QUALITY).index_by(&:item_id) : {}

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
            end
          when "Item"
            if (ui = user_items_by_id[rr.component_id])
              ui.decrement!(:quantity, rr.quantity)
            end
          end
        end

        user_item = @user.user_items.find_or_initialize_by(item: recipe.item, quality: DEFAULT_QUALITY)
        user_item.quantity = user_item.quantity.to_i + 1
        user_item.save!

        # Evaluate flags potentially satisfied by crafting this item within the transaction
        EnsureFlagsService.evaluate_for(@user, touch: { items: [ recipe.item_id ] })
      end

      # Broadcast deltas after commit so clients see committed state
      res_changes = selected.select { |rr| rr.component_type == 'Resource' }.map do |rr|
        ur = @user.user_resources.find_by(resource_id: rr.component_id)
        { resource_id: rr.component_id, amount: ur&.amount.to_i }
      end
      # Include crafted item increment
      item_change_ids = selected.select { |rr| rr.component_type == 'Item' }.map(&:component_id)
      item_change_ids << recipe.item_id
      item_changes = item_change_ids.uniq.map do |iid|
        ui = @user.user_items.find_by(item_id: iid, quality: DEFAULT_QUALITY)
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
