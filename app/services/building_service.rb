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
    user_building = @user.user_buildings.find_or_create_by(building: building) do |ub|
      ub.level = 1
    end
    { success: true, message: "#{building.name} constructed successfully." }
  end

  def upgrade_building(user_building_id)
    user_building = @user.user_buildings.find(user_building_id)
    current_level = user_building.level || 1
    cost = cost_for_level(current_level + 1)
    return { success: false, error: "Not enough resources." } unless resources_sufficient?(cost)

    deduct_resources(cost)
    user_building.update!(level: current_level + 1)
    { success: true, message: "#{user_building.building.name} upgraded successfully." }
  end

  private

  def cost_for_level(level)
    Resource.all.each_with_object({}) do |resource, hash|
      hash[resource] = resource.base_amount * level
    end
  end

  def resources_sufficient?(cost)
    user_resources = @user.user_resources
    return false unless user_resources.exists?

    cost.all? do |resource, amount|
      scope = user_resources.where(resource: resource)
      # If the user doesn't track this resource yet, ignore it for sufficiency.
      next true if scope.blank?
      scope.sum(:amount) >= amount
    end
  end

  def deduct_resources(cost)
    cost.each do |resource, amount|
      records = @user.user_resources.where(resource: resource).order(:id)
      total = records.sum(:amount)
      next if total <= 0

      new_total = total - amount
      new_total = 0 if new_total.negative?

      if records.any?
        primary = records.first
        primary.update!(amount: new_total)
        records.offset(1).delete_all
      else
        @user.user_resources.create!(resource: resource, amount: new_total)
      end
    end
  end
end
