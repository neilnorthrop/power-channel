# frozen_string_literal: true

class Api::V1::BuildingsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    buildings = Building.all
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: 'Building', unlockable_id: buildings.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_building_ids = buildings.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_buildings = buildings.select { |b| visible_building_ids.include?(b.id) }
    flag_ids = gates.values.compact.uniq
    requirement_names = RequirementNameLookup.for_flag_ids(flag_ids)
    options = { params: { current_user: @current_user, gates: { 'Building' => gates }, user_flag_ids: user_flag_ids, requirement_names: requirement_names } }
    render json: BuildingSerializer.new(visible_buildings, options).serializable_hash.to_json
  end

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
