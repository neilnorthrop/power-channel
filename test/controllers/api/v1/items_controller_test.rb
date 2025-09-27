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
    UserItem.where(user: @user, item: @item, quality: "normal").delete_all
    assert_difference("UserItem.where(user: @user, item: @item, quality: 'normal').count", +1) do
      post api_v1_items_url, params: { item_id: @item.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :success
    ui = UserItem.find_by(user: @user, item: @item, quality: "normal")
    assert_equal 1, ui.quantity
  end

  test "create with invalid item id returns 404 and no change" do
    assert_no_difference("UserItem.count") do
      post api_v1_items_url, params: { item_id: -1 }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :not_found
  end

  test "creating the same item twice increments quantity instead of new row" do
    UserItem.where(user: @user, item: @item, quality: "normal").delete_all
    2.times do
      post api_v1_items_url, params: { item_id: @item.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
      assert_response :success
    end
    ui = UserItem.find_by(user: @user, item: @item, quality: "normal")
    assert_equal 1, UserItem.where(user: @user, item: @item, quality: "normal").count
    assert_equal 2, ui.quantity
  end

  test "should use item" do
    user_item = @user.user_items.create!(item: @item, quality: "normal")

    assert_difference("UserItem.where(user: @user, item: @item, quality: 'normal').count", -1) do
      post use_api_v1_item_url(user_item.item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :success
    body = JSON.parse(@response.body)
    assert_match(/applied\.?\z/, body["message"])
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
    # Create two qualities for the same item
    @user.user_items.create!(item: @item, quality: "normal")
    @user.user_items.create!(item: @item, quality: "rare")

    # Use rare specifically
    assert_difference("UserItem.where(user: @user, item: @item).count", -1) do
      post use_api_v1_item_url(@item), params: { quality: "rare" }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :success
    remaining = UserItem.where(user: @user, item: @item).pluck(:quality)
    assert_equal [ "normal" ], remaining
  end

  test "use defaults to normal quality when not provided" do
    UserItem.where(user: @user, item: @item).delete_all
    @user.user_items.create!(item: @item, quality: "normal")
    post use_api_v1_item_url(@item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    assert_nil UserItem.find_by(user: @user, item: @item, quality: "normal")
  end

  test "use returns 422 and preserves item when effect fails" do
    unusable_item = items(:twine)
    UserItem.where(user: @user, item: unusable_item).delete_all
    @user.user_items.create!(item: unusable_item, quality: "normal", quantity: 1)

    assert_no_difference("UserItem.where(user: @user, item: unusable_item, quality: 'normal').count") do
      post use_api_v1_item_url(unusable_item), headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_equal "Item cannot be used.", body["error"]
    assert UserItem.exists?(user: @user, item: unusable_item, quality: "normal")
  end
end
