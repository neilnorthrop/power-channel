# frozen_string_literal: true

require "test_helper"

class Api::V1::DismantleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @hatchet = items(:hatchet)
    @twine = items(:twine)
    @stone = resources(:stone)
    @user.user_items.where(item: @hatchet).delete_all
    @user.user_items.where(item: @twine).delete_all
    @user.user_resources.where(resource: @stone).delete_all
    @user.user_items.create!(item: @hatchet, quantity: 1, quality: "normal")
  end

  test "dismantle returns success and updates inventory" do
    post api_v1_dismantle_index_url, params: { item_id: @hatchet.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    assert_nil @user.user_items.find_by(item: @hatchet)
    assert_equal 1, @user.user_items.find_by(item: @twine).quantity
    assert_equal 3, @user.user_resources.find_by(resource: @stone).amount
  end

  test "dismantle fails without inventory" do
    @user.user_items.where(item: @hatchet).delete_all
    post api_v1_dismantle_index_url, params: { item_id: @hatchet.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :unprocessable_entity
  end
end

