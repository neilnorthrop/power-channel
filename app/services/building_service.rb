# frozen_string_literal: true

class BuildingService
  def initialize(user)
    @user = user
  end

  def create_building(building_id)
    building = Building.find(building_id)
    cost = cost_for_level(1)
    return { success: false, error: "Not enough resources." } unless resources_sufficient?(cost)

    deduct_resources(cost)
    user_building = @user.user_buildings.find_or_create_by(building: building)
    { success: true, message: "#{building.name} constructed successfully." }
  end

  def upgrade_building(user_building_id)
    user_building = @user.user_buildings.find(user_building_id)
    cost = cost_for_level(user_building.level + 1)
    return { success: false, error: "Not enough resources." } unless resources_sufficient?(cost)

    deduct_resources(cost)
    user_building.increment!(:level)
    { success: true, message: "#{user_building.building.name} upgraded successfully." }
  end

  private

  def cost_for_level(level)
    Resource.all.each_with_object({}) do |resource, hash|
      hash[resource] = resource.base_amount * level
    end
  end

  def resources_sufficient?(cost)
    cost.all? do |resource, amount|
      @user.user_resources.find_by(resource: resource)&.amount.to_i >= amount
    end
  end

  def deduct_resources(cost)
    cost.each do |resource, amount|
      user_resource = @user.user_resources.find_by(resource: resource)
      user_resource&.decrement!(:amount, amount)
    end
  end
end
