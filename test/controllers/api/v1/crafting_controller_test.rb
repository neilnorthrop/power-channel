# frozen_string_literal: true

require 'test_helper'

class Api::V1::CraftingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @recipe = recipes(:one)
    @resource = resources(:one)
    @recipe.recipe_resources.create(resource: @resource, quantity: 1)
    @user.user_resources.create(resource: @resource, amount: 1)
  end

  test 'should get index' do
    get api_v1_crafting_index_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test 'should create crafting' do
    assert_difference('UserItem.count') do
      post api_v1_crafting_index_url, params: { recipe_id: @recipe.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end
end
