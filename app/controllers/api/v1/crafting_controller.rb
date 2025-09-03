# frozen_string_literal: true

class Api::V1::CraftingController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    recipes = Recipe.all.includes(:recipe_resources, :item)
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: 'Recipe', unlockable_id: recipes.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_recipe_ids = recipes.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_recipes = recipes.select { |r| visible_recipe_ids.include?(r.id) }

    # Also pass item gates to avoid per-item lookups in ItemSerializer for included items
    item_ids = visible_recipes.map(&:item_id).compact.uniq
    item_gates = Unlockable.where(unlockable_type: 'Item', unlockable_id: item_ids).pluck(:unlockable_id, :flag_id).to_h

    # Prefetch component names for recipe_resources to avoid per-row lookups in RecipeResourceSerializer
    rr = visible_recipes.flat_map(&:recipe_resources)
    resource_ids = rr.select { |x| x.component_type == 'Resource' }.map(&:component_id).uniq
    item_component_ids = rr.select { |x| x.component_type == 'Item' }.map(&:component_id).uniq
    component_names = {}
    component_names['Resource'] = Resource.where(id: resource_ids).pluck(:id, :name).to_h if resource_ids.any?
    component_names['Item']     = Item.where(id: item_component_ids).pluck(:id, :name).to_h if item_component_ids.any?

    options = { include: [ :item, :recipe_resources ], params: { current_user: @current_user, gates: { 'Recipe' => gates, 'Item' => item_gates }, user_flag_ids: user_flag_ids, component_names: component_names } }
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
