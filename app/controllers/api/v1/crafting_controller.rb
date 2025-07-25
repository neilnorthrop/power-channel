# frozen_string_literal: true

class Api::V1::CraftingController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    recipes = Recipe.all
    options = { include: [:item] }
    render json: RecipeSerializer.new(recipes, options).serializable_hash.to_json
  end

  def create
    recipe = Recipe.find(params[:recipe_id])
    can_craft = true
    recipe.recipe_resources.each do |recipe_resource|
      user_resource = @current_user.user_resources.find_by(resource: recipe_resource.resource)
      if user_resource.nil? || user_resource.amount < recipe_resource.quantity
        can_craft = false
        break
      end
    end

    if can_craft
      recipe.recipe_resources.each do |recipe_resource|
        user_resource = @current_user.user_resources.find_by(resource: recipe_resource.resource)
        user_resource.decrement!(:amount, recipe_resource.quantity)
      end
      @current_user.items << recipe.item
      render json: { message: "#{recipe.item.name} crafted successfully." }
    else
      render json: { error: 'Not enough resources.' }, status: :unprocessable_entity
    end
  end
end
