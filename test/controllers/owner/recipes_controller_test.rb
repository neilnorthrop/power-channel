# frozen_string_literal: true

require "test_helper"

class Owner::RecipesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "recipes-owner@example.com", password: "password", role: :owner)
    sign_in @owner, scope: :user
  end

  test "new renders owner validate recipes helper" do
    Item.create!(name: "Iron Nugget")
    Resource.create!(name: "Ore", description: "", base_amount: 1)

    get new_owner_recipe_path

    assert_response :success
    assert_includes @response.body, owner_validate_recipes_path
  end

  test "edit renders owner validate recipe helper" do
    item = Item.create!(name: "Iron Bar")
    recipe = Recipe.create!(item: item, quantity: 1)

    get edit_owner_recipe_path(recipe)

    assert_response :success
    assert_includes @response.body, owner_validate_recipe_path(recipe)
  end
end
