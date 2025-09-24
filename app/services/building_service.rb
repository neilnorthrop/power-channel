# frozen_string_literal: true

class BuildingService
  def initialize(user)
    @user = user
  end

  def create_building(building_id)
    building = Building.find(building_id)
    cost = cost_for_level(1)
    sums = @user.user_resources.group(:resource_id).sum(:amount)
    return { success: false, error: "Not enough resources." } unless resources_sufficient?(cost, sums)

    deduct_resources(cost, sums)
    user_building = @user.user_buildings.find_or_create_by(building: building) do |ub|
      ub.level = 1
    end
    EnsureFlagsService.evaluate_for(@user, touch: { buildings: [building.id] })
    { success: true, message: "#{building.name} constructed successfully." }
  end

  def upgrade_building(user_building_id)
    user_building = @user.user_buildings.find(user_building_id)
    current_level = user_building.level || 1
    cost = cost_for_level(current_level + 1)
    sums = @user.user_resources.group(:resource_id).sum(:amount)
    return { success: false, error: "Not enough resources." } unless resources_sufficient?(cost, sums)

    deduct_resources(cost, sums)
    user_building.update!(level: current_level + 1)
    EnsureFlagsService.evaluate_for(@user, touch: { buildings: [user_building.building_id] })
    { success: true, message: "#{user_building.building.name} upgraded successfully." }
  end

  private

  def cost_for_level(level)
    Resource.all.each_with_object({}) do |resource, hash|
      hash[resource] = resource.base_amount * level
    end
  end

  def resources_sufficient?(cost, amounts_by_resource_id = nil)
    user_resources = @user.user_resources
    return false unless user_resources.exists?

    amounts_by_resource_id ||= user_resources.group(:resource_id).sum(:amount)
    cost.all? do |resource, amount|
      sum = amounts_by_resource_id[resource.id]
      # If the user doesn't track this resource yet, ignore it for sufficiency.
      sum.nil? ? true : sum.to_i >= amount
    end
  end

  def deduct_resources(cost, amounts_by_resource_id = nil)
    amounts_by_resource_id ||= @user.user_resources.group(:resource_id).sum(:amount)
    resource_ids = cost.keys.map(&:id)
    # Preload all user resource rows for the relevant resources in one query
    rows = @user.user_resources.where(resource_id: resource_ids).order(:resource_id, :id).to_a
    rows_by_resource = rows.group_by(&:resource_id)

    # Update first row per resource to new total; delete duplicates
    ids_to_delete = []
    cost.each do |resource, amount|
      rid = resource.id
      total = amounts_by_resource_id[rid].to_i
      next if total <= 0
      new_total = total - amount
      new_total = 0 if new_total.negative?

      list = rows_by_resource[rid] || []
      if list.any?
        primary = list.first
        primary.update!(amount: new_total)
        ids_to_delete.concat(list.drop(1).map(&:id)) if list.size > 1
      else
        @user.user_resources.create!(resource_id: rid, amount: new_total)
      end
    end
    # Delete duplicates in a single statement if any
    if ids_to_delete.any?
      @user.user_resources.where(id: ids_to_delete).delete_all
    end
  end
end
