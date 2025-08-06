# frozen_string_literal: true

class BuildingService
  def initialize(user)
    @user = user
  end

  def create_building(building_id)
    building = Building.find(building_id)
    # This is a placeholder for resource checking.
    # In a real application, you would check if the user has enough resources to build.
    user_building = @user.user_buildings.find_or_create_by(building: building)
    { success: true, message: "#{building.name} constructed successfully." }
  end

  def upgrade_building(user_building_id)
    user_building = @user.user_buildings.find(user_building_id)
    # This is a placeholder for resource checking.
    # In a real application, you would check if the user has enough resources to upgrade.
    user_building.increment!(:level)
    { success: true, message: "#{user_building.building.name} upgraded successfully." }
  end
end
