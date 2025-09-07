# frozen_string_literal: true

require "test_helper"

class CraftingAndDismantleFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @wood = resources(:wood)
    @twine = items(:twine)
    @hatchet = items(:hatchet)
    @hatchet_recipe = recipes(:hatchet_recipe)

    # Reset relevant inventory
    @user.user_resources.where(resource: @wood).delete_all
    @user.user_items.where(item: @twine).delete_all
    @user.user_items.where(item: @hatchet).delete_all

    @user.user_resources.create!(resource: @wood, amount: 20)
    @user.user_items.create!(item: @twine, quantity: 2, quality: "normal")
  end

  test "craft hatchet then dismantle it" do
    # Craft
    post api_v1_crafting_index_url, params: { recipe_id: @hatchet_recipe.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    assert_equal 1, @user.user_items.find_by(item: @hatchet)&.quantity
    assert_equal 10, @user.user_resources.find_by(resource: @wood)&.amount
    assert_equal 0, @user.user_items.find_by(item: @twine)&.reload&.quantity

    # Dismantle
    post api_v1_dismantle_index_url, params: { item_id: @hatchet.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    assert_nil @user.user_items.find_by(item: @hatchet)
    assert_equal 1, @user.user_items.find_by(item: @twine).quantity
  end
end

