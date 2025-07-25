# frozen_string_literal: true

class Api::V1::BuildingsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    buildings = Building.all
    render json: BuildingSerializer.new(buildings).serializable_hash.to_json
  end

  def create
    building = Building.find(params[:building_id])
    user_building = @current_user.user_buildings.find_or_create_by(building: building)
    # Implement resource checking and consumption here
    render json: { message: "#{building.name} constructed successfully." }
  end

  def update
    user_building = @current_user.user_buildings.find(params[:id])
    # Implement resource checking and consumption here
    user_building.increment!(:level)
    render json: { message: "#{user_building.building.name} upgraded successfully." }
  end
end
