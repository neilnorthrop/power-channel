# frozen_string_literal: true

class CraftingService
  def initialize(user)
    @user = user
  end

  def craft_item(recipe_id)
    recipe = Recipe.find(recipe_id)
    can_craft = true
    recipe.recipe_resources.each do |rr|
      case rr.component_type
      when 'Resource'
        ur = @user.user_resources.find_by(resource_id: rr.component_id)
        if ur.nil? || ur.amount.to_i < rr.quantity
          can_craft = false
          break
        end
      when 'Item'
        ui = @user.user_items.find_by(item_id: rr.component_id)
        if ui.nil? || ui.quantity.to_i < rr.quantity
          can_craft = false
          break
        end
      else
        # Unknown component type blocks crafting for safety
        can_craft = false
        break
      end
    end

    if can_craft
      recipe.recipe_resources.each do |rr|
        case rr.component_type
        when 'Resource'
          ur = @user.user_resources.find_by(resource_id: rr.component_id)
          ur.decrement!(:amount, rr.quantity)
        when 'Item'
          ui = @user.user_items.find_by(item_id: rr.component_id)
          ui.decrement!(:quantity, rr.quantity)
        end
      end
      user_item = @user.user_items.find_or_initialize_by(item: recipe.item)
      user_item.quantity = user_item.quantity.to_i + 1
      user_item.save!
      @user.save
      # Evaluate flags potentially satisfied by crafting this item
      EnsureFlagsService.evaluate_for(@user, touch: { items: [recipe.item_id] })
      UserUpdatesChannel.broadcast_to(@user, { type: "user_resource_update", data: UserResourcesSerializer.new(@user.user_resources).serializable_hash })
      UserUpdatesChannel.broadcast_to(@user, { type: "user_item_update", data: UserItemSerializer.new(@user.user_items).serializable_hash })
      { success: true, message: "#{recipe.item.name} crafted successfully." }
    else
      { success: false, error: "Not enough resources." }
    end
  end
end
