# frozen_string_literal: true

class Api::V1::CraftingController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    recipes = Recipe.all
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: 'Recipe', unlockable_id: recipes.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_recipe_ids = recipes.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_recipes = recipes.select { |r| visible_recipe_ids.include?(r.id) }

    # Also pass item gates to avoid per-item lookups in ItemSerializer for included items
    item_ids = visible_recipes.map(&:item_id).compact.uniq
    item_gates = Unlockable.where(unlockable_type: 'Item', unlockable_id: item_ids).pluck(:unlockable_id, :flag_id).to_h

    options = { include: [ :item ], params: { current_user: @current_user, gates: { 'Recipe' => gates, 'Item' => item_gates }, user_flag_ids: user_flag_ids } }
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
