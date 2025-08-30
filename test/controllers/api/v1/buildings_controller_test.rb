# frozen_string_literal: true

require "test_helper"

class Api::V1::BuildingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @building = buildings(:one)
  end

  test "should get index" do
    get api_v1_buildings_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "should create building" do
    @user.user_buildings.destroy_all
    assert_difference("UserBuilding.count") do
      post api_v1_buildings_url, params: { building_id: @building.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end

  test "should update building" do
    skip
    user_building = @user.user_buildings.create(building: @building)
    patch api_v1_building_url(user_building), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end
end
