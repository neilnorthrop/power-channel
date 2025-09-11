# frozen_string_literal: true

require "test_helper"

class CraftingServiceOrGroupsTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @user.user_items.destroy_all
    @user.user_resources.destroy_all

    @twine = Item.create!(name: 'Twine')
    @reeds = Resource.create!(name: 'Reeds', base_amount: 0)
    @fibers = Resource.create!(name: 'Plant Fibers', base_amount: 0)

    @recipe = Recipe.create!(item: @twine, quantity: 1)
    # OR group: group_key 'binding'
    RecipeResource.create!(recipe: @recipe, component: @reeds, quantity: 2, group_key: 'binding', logic: 'OR')
    RecipeResource.create!(recipe: @recipe, component: @fibers, quantity: 4, group_key: 'binding', logic: 'OR')
  end

  test "crafts with reeds only and consumes reeds" do
    @user.user_resources.create!(resource: @reeds, amount: 2)
    @user.user_resources.create!(resource: @fibers, amount: 0)

    result = CraftingService.new(@user).craft_item(@recipe.id)
    assert result[:success]
    assert_equal 0, @user.user_resources.find_by(resource: @reeds).reload.amount
  end

  test "crafts with fibers only and consumes fibers" do
    @user.user_resources.create!(resource: @reeds, amount: 0)
    @user.user_resources.create!(resource: @fibers, amount: 4)

    result = CraftingService.new(@user).craft_item(@recipe.id)
    assert result[:success]
    assert_equal 0, @user.user_resources.find_by(resource: @fibers).reload.amount
  end

  test "fails when neither sufficient" do
    @user.user_resources.create!(resource: @reeds, amount: 1)
    @user.user_resources.create!(resource: @fibers, amount: 3)

    result = CraftingService.new(@user).craft_item(@recipe.id)
    assert_not result[:success]
  end
end

