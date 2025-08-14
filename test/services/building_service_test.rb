# frozen_string_literal: true

require "test_helper"

class BuildingServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @service = BuildingService.new(@user)
  end

  test "create_building adds building to user" do
    building = buildings(:two)
    assert_nil @user.user_buildings.find_by(building: building)

    result = @service.create_building(building.id)

    assert result[:success]
    assert_not_nil @user.user_buildings.find_by(building: building)
  end

  test "upgrade_building increases level" do
    user_building = user_buildings(:one)

    result = @service.upgrade_building(user_building.id)

    assert result[:success]
    assert_equal 2, user_building.reload.level
  end
end
