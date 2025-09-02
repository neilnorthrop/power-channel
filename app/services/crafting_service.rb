# frozen_string_literal: true

class CraftingService
  def initialize(user)
    @user = user
  end

  def craft_item(recipe_id)
    recipe = Recipe.find(recipe_id)
    can_craft = true
    recipe.recipe_resources.each do |recipe_resource|
      user_resource = @user.user_resources.find_by(resource: recipe_resource.resource)
      if user_resource.nil? || user_resource.amount < recipe_resource.quantity
        can_craft = false
        break
      end
    end

    if can_craft
      recipe.recipe_resources.each do |recipe_resource|
        user_resource = @user.user_resources.find_by(resource: recipe_resource.resource)
        user_resource.decrement!(:amount, recipe_resource.quantity)
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
