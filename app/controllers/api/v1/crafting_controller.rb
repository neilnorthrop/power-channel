# frozen_string_literal: true

class Api::V1::CraftingController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    recipes = Recipe.all
    # Hide gated recipes the user hasn't unlocked yet
    visible_recipes = recipes.select do |r|
      if (gate = Unlockable.find_by(unlockable_type: 'Recipe', unlockable_id: r.id))
        @current_user.user_flags.exists?(flag_id: gate.flag_id)
      else
        true
      end
    end
    options = { include: [ :item ], params: { current_user: @current_user } }
    render json: RecipeSerializer.new(visible_recipes, options).serializable_hash.to_json
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
