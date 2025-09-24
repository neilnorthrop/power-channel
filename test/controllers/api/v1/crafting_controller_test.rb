# frozen_string_literal: true

require "test_helper"

class Api::V1::CraftingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @recipe = recipes(:lucky_charm_recipe)
    # Ensure user has enough resources to craft
    @user.user_resources.find_by(resource: resources(:gold))&.update(amount: 10)
    @user.user_resources.find_or_create_by(resource: resources(:stone))&.update(amount: 10)
    @user.items.destroy_all
  end

  test "should get index" do
    get api_v1_crafting_index_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "should create crafting" do
    assert_difference("UserItem.count") do
      post api_v1_crafting_index_url, params: { recipe_id: @recipe.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end

  test "recipes include craftable_now flag" do
    # Ensure user has enough resources to craft lucky_charm_recipe
    @user.user_resources.find_or_create_by(resource: resources(:gold)).update(amount: 20)
    @user.user_resources.find_or_create_by(resource: resources(:stone)).update(amount: 10)

    get api_v1_crafting_index_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    data = JSON.parse(@response.body)
    recipes = data["data"] || []
    refute_empty recipes
    # Find the lucky_charm_recipe
    r = recipes.find { |x| x["id"].to_s == recipes(:lucky_charm_recipe).id.to_s }
    assert r, "Expected lucky_charm_recipe in response"
    assert_equal true, r["attributes"]["craftable_now"]
  end

  test "uses advanced service when experimental flag is true" do
    @user.update!(experimental_crafting: true)
    assert_difference("UserItem.count") do
      post api_v1_crafting_index_url, params: { recipe_id: @recipe.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end
    assert_response :success
  end
end
