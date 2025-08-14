# frozen_string_literal: true

require "test_helper"

class BuildingServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "builder@example.com", password: "password")
    Resource.all.each do |resource|
      @user.user_resources.create!(resource: resource, amount: 100)
    end
    @service = BuildingService.new(@user)
    @building = Building.create!(name: "Mill", description: "desc", level: 1, effect: "increase_wood_production")
  end

  test "create_building deducts resources and adds building" do
    result = @service.create_building(@building.id)
    assert result[:success]
    assert_not_nil @user.user_buildings.find_by(building: @building)
    Resource.all.each do |resource|
      assert_equal 100 - resource.base_amount, @user.user_resources.find_by(resource: resource).amount
    end
  end

  test "create_building fails with insufficient resources" do
    poor_user = User.create!(email: "poor@example.com", password: "password")
    service = BuildingService.new(poor_user)
    result = service.create_building(@building.id)
    assert_not result[:success]
  end

  test "upgrade_building increases level and deducts resources" do
    @service.create_building(@building.id)
    user_building = @user.user_buildings.find_by(building: @building)
    result = @service.upgrade_building(user_building.id)
    assert result[:success]
    assert_equal 2, user_building.reload.level
  end
end
