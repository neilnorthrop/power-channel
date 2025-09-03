# frozen_string_literal: true

class CraftingService
  def initialize(user)
    @user = user
  end

  def craft_item(recipe_id)
    recipe = Recipe.find(recipe_id)
    reqs = recipe.recipe_resources.to_a

    # Preload user state for relevant component ids
    resource_ids = reqs.select { |rr| rr.component_type == 'Resource' }.map(&:component_id)
    item_ids     = reqs.select { |rr| rr.component_type == 'Item' }.map(&:component_id)
    user_resources_by_id = resource_ids.any? ? @user.user_resources.where(resource_id: resource_ids).index_by(&:resource_id) : {}
    user_items_by_id     = item_ids.any?     ? @user.user_items.where(item_id: item_ids).index_by(&:item_id)           : {}

    # Verify availability
    can_craft = reqs.all? do |rr|
      case rr.component_type
      when 'Resource'
        ur = user_resources_by_id[rr.component_id]
        ur && ur.amount.to_i >= rr.quantity
      when 'Item'
        ui = user_items_by_id[rr.component_id]
        ui && ui.quantity.to_i >= rr.quantity
      else
        false
      end
    end

    if can_craft
      # Perform the entire craft atomically
      ApplicationRecord.transaction do
        reqs.each do |rr|
          case rr.component_type
          when 'Resource'
            if (ur = user_resources_by_id[rr.component_id])
              ur.decrement!(:amount, rr.quantity)
            end
          when 'Item'
            if (ui = user_items_by_id[rr.component_id])
              ui.decrement!(:quantity, rr.quantity)
            end
          end
        end

        user_item = @user.user_items.find_or_initialize_by(item: recipe.item)
        user_item.quantity = user_item.quantity.to_i + 1
        user_item.save!

        # Evaluate flags potentially satisfied by crafting this item within the transaction
        EnsureFlagsService.evaluate_for(@user, touch: { items: [recipe.item_id] })
      end

      # Broadcast after commit so clients see committed state
      user_items = @user.user_items.includes(:item)
      item_ids = user_items.map(&:item_id).uniq
      items_with_effects = Effect.where(effectable_type: 'Item', effectable_id: item_ids).distinct.pluck(:effectable_id).to_set
      UserUpdatesChannel.broadcast_to(@user, { type: "user_resource_update", data: UserResourcesSerializer.new(@user.user_resources.includes(:resource)).serializable_hash })
      UserUpdatesChannel.broadcast_to(@user, { type: "user_item_update", data: UserItemSerializer.new(user_items, { params: { items_with_effects: items_with_effects } }).serializable_hash })
      Event.create!(user: @user, level: 'info', message: "Crafted item: #{recipe.item.name}")
      { success: true, message: "#{recipe.item.name} crafted successfully." }
    else
      Event.create!(user: @user, level: 'warning', message: "Failed to craft (insufficient resources): #{recipe.item.name}")
      { success: false, error: "Not enough resources." }
    end
  end
end
