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
      @user.items << recipe.item
      { success: true, message: "#{recipe.item.name} crafted successfully." }
    else
      { success: false, error: 'Not enough resources.' }
    end
  end
end
