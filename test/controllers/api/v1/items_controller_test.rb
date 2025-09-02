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

  test "index without auth returns 401" do
    get api_v1_items_url, as: :json
    assert_response :unauthorized
    body = JSON.parse(@response.body)
    assert_includes body.keys, "errors"
  end

  test "should create item" do
    assert_difference("UserItem.count") do
      post api_v1_items_url, params: { item_id: @item.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end

  test "create with invalid item id returns 404 and no change" do
    assert_no_difference("UserItem.count") do
      post api_v1_items_url, params: { item_id: -1 }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :not_found
  end

  test "creating the same item twice creates two rows (duplicates allowed)" do
    # Ensure deterministic start: remove existing records for this item/user
    UserItem.where(user: @user, item: @item).delete_all
    assert_difference("UserItem.where(user: @user, item: @item).count", +2) do
      2.times do
        post api_v1_items_url, params: { item_id: @item.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
      end
    end
  end

  test "should use item" do
    user_item = @user.user_items.create(item: @item)
    post use_api_v1_item_url(user_item.item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "use returns 404 when not in inventory" do
    @user.user_items.where(item: @item).delete_all
    post use_api_v1_item_url(@item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :not_found
    body = JSON.parse(@response.body)
    assert_equal "Item not found in inventory.", body["error"]
  end

  test "use removes only one record when duplicates exist" do
    UserItem.where(user: @user, item: @item).delete_all
    2.times { @user.user_items.create!(item: @item) }
    assert_difference("UserItem.where(user: @user, item: @item).count", -1) do
      post use_api_v1_item_url(@item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :success
    assert_equal 1, UserItem.where(user: @user, item: @item).count
  end
end
