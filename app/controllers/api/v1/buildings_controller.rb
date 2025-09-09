# frozen_string_literal: true

class Api::V1::BuildingsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/buildings
  # Returns a list of buildings available to the current user, filtered by unlockable gates and sorted by building name.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "name": "Woodcutter's Hut",
  #     "description": "A small hut for cutting wood.",
  #     "base_amount": 10
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of buildings with associated details, filtered and sorted for the current user
  # @example GET /api/v1/buildings
  #   curl -X GET "https://example.com/api/v1/buildings"
  def index
    buildings = Building.all
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: "Building", unlockable_id: buildings.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_building_ids = buildings.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_buildings = buildings.select { |b| visible_building_ids.include?(b.id) }
    flag_ids = gates.values.compact.uniq
    requirement_names = RequirementNameLookup.for_flag_ids(flag_ids)
    options = { params: { current_user: @current_user, gates: { "Building" => gates }, user_flag_ids: user_flag_ids, requirement_names: requirement_names } }
    render json: BuildingSerializer.new(visible_buildings, options).serializable_hash.to_json
  end

  # POST /api/v1/buildings
  # Create a new building for the current user, checking for unlockable requirements and resources.
  # Example return value:
  # {
  #   "message": "Building created successfully."
  # }
  # @return [JSON] a JSON object indicating the success of the creation operation or any error details
  # @example POST /api/v1/buildings
  #   curl -X POST "https://example.com/api/v1/buildings" -d '{"building_id": 1}'
  def create
    building_service = BuildingService.new(@current_user)
    result = building_service.create_building(params[:building_id])
    if result[:success]
      UserUpdatesChannel.broadcast_to(@current_user, { type: "user_building_update", data: UserBuildingSerializer.new(@current_user.user_buildings).serializable_hash })
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/buildings/:id
  # Upgrade a building for the current user, increasing its level and potentially unlocking new features or benefits associated with that building.
  # Example return value:
  # {
  #   "message": "Building upgraded successfully."
  # }
  # @return [JSON] a JSON object indicating the success of the upgrade operation or any error details
  # @example PATCH /api/v1/buildings/1
  #   curl -X PATCH "https://example.com/api/v1/buildings/1"
  def update
    building_service = BuildingService.new(@current_user)
    result = building_service.upgrade_building(params[:id])
    if result[:success]
      UserUpdatesChannel.broadcast_to(@current_user, { type: "user_building_update", data: UserBuildingSerializer.new(@current_user.user_buildings).serializable_hash })
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
