# frozen_string_literal: true

class Api::V1::CraftingController < Api::ApiController
  include Authenticable

  # GET /api/v1/crafting
  # Returns a list of recipes available to the current user, filtered by unlockable gates.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "item_id": 1,
  #     "item": {
  #       "id": 1,
  #       "name": "Wooden Sword",
  #       "description": "A basic wooden sword.",
  #       "effect": "sword_effect"
  #     },
  #     "recipe_resources": [
  #       {
  #         "id": 1,
  #         "recipe_id": 1,
  #         "component_type": "Resource",
  #         "component_id": 1,
  #         "quantity": 5,
  #         "component_name": "Wood"
  #       },
  #       ...
  #     ]
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of recipes with associated details, filtered and sorted for the current user
  # @example GET /api/v1/crafting
  #   curl -X GET "https://example.com/api/v1/crafting"
  def index
    recipes = Recipe.all.includes(:recipe_resources, :item)
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: "Recipe", unlockable_id: recipes.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_recipe_ids = recipes.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_recipes = recipes.select { |r| visible_recipe_ids.include?(r.id) }

    # Also pass item gates to avoid per-item lookups in ItemSerializer for included items
    item_ids = visible_recipes.map(&:item_id).compact.uniq
    item_gates = Unlockable.where(unlockable_type: "Item", unlockable_id: item_ids).pluck(:unlockable_id, :flag_id).to_h

    # Prefetch component names for recipe_resources to avoid per-row lookups in RecipeResourceSerializer
    rr = visible_recipes.flat_map(&:recipe_resources)
    resource_ids = rr.select { |x| x.component_type == "Resource" }.map(&:component_id).uniq
    item_component_ids = rr.select { |x| x.component_type == "Item" }.map(&:component_id).uniq
    component_names = {}
    component_names["Resource"] = Resource.where(id: resource_ids).pluck(:id, :name).to_h if resource_ids.any?
    component_names["Item"]     = Item.where(id: item_component_ids).pluck(:id, :name).to_h if item_component_ids.any?

    # Prefetch requirement names for recipe flags
    flag_ids = gates.values.compact.uniq
    requirement_names = RequirementNameLookup.for_flag_ids(flag_ids)

    # Prefetch user state maps to compute craftable_now server-side
    user_resources_by_id = resource_ids.any? ? @current_user.user_resources.where(resource_id: resource_ids).pluck(:resource_id, :amount).to_h : {}
    user_items_by_id     = item_component_ids.any? ? @current_user.user_items.where(item_id: item_component_ids, quality: CraftingService::DEFAULT_QUALITY).pluck(:item_id, :quantity).to_h : {}

    options = { include: [ :item, :recipe_resources ], params: { current_user: @current_user, gates: { "Recipe" => gates, "Item" => item_gates }, user_flag_ids: user_flag_ids, component_names: component_names, requirement_names: requirement_names, user_resources_by_id: user_resources_by_id, user_items_by_id: user_items_by_id } }
    render json: RecipeSerializer.new(visible_recipes, options).serializable_hash.to_json
  end

  # POST /api/v1/crafting
  # Craft an item for the current user based on the provided recipe ID, checking for unlockable requirements and available resources.
  # Example return value:
  # {
  #   "message": "1 Item crafted!"
  # }
  # @return [JSON] a JSON object indicating the success of the crafting operation or any error details
  # @example POST /api/v1/crafting
  #   curl -X POST "https://example.com/api/v1/crafting" -d '{"recipe_id": 1}'
  def create
    service_class = @current_user.experimental_crafting? ? AdvancedCraftingService : CraftingService
    crafting_service = service_class.new(@current_user)
    result = crafting_service.craft_item(params[:recipe_id])

    if result[:success]
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
