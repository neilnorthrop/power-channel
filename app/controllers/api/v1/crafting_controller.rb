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
    crafting_service = CraftingService.new(@current_user)
    result = crafting_service.craft_item(params[:recipe_id])

    if result[:success]
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
