# frozen_string_literal: true

class Api::V1::BuildingsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    buildings = Building.all
    # Hide gated buildings the user hasn't unlocked yet
    visible_buildings = buildings.select do |b|
      if (gate = Unlockable.find_by(unlockable_type: 'Building', unlockable_id: b.id))
        @current_user.user_flags.exists?(flag_id: gate.flag_id)
      else
        true
      end
    end
    options = { params: { current_user: @current_user } }
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
