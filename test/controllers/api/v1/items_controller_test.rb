# frozen_string_literal: true

require "test_helper"

class Api::V1::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @item = items(:one)
  end

  test "should get index" do
    get api_v1_items_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "should create item" do
    assert_difference("UserItem.count") do
      post api_v1_items_url, params: { item_id: @item.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end

  test "should use item" do
    user_item = @user.user_items.create(item: @item)
    post use_api_v1_item_url(user_item.item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end
end
