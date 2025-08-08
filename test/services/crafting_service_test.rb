# frozen_string_literal: true

require "test_helper"

class CraftingServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @recipe = recipes(:one)
    @item = items(:one)
    @resource = resources(:one)
    @recipe.update(item: @item)
    @user.items.destroy_all
    @user.user_resources.destroy_all
    @recipe.recipe_resources.destroy_all
    @recipe.recipe_resources.create(resource: @resource, quantity: 1)
    @user.user_resources.create(resource: @resource, amount: 1)
  end

  test "should craft item and decrement resources" do
    service = CraftingService.new(@user)
    initial_item_count = @user.items.count
    initial_resource_amount = @user.user_resources.find_by(resource: @resource).amount

    assert initial_item_count.zero?, @user.items.inspect
    assert_equal 1, initial_resource_amount

    result = service.craft_item(@recipe.id)

    assert result[:success]
    assert_equal initial_item_count + 1, @user.reload.items.count, @user.items.inspect
    assert_equal initial_resource_amount - 1, @user.user_resources.find_by(resource: @resource).amount
  end

  test "should not craft item if not enough resources" do
    service = CraftingService.new(@user)
    @user.user_resources.find_by(resource: @resource).update(amount: 0)
    result = service.craft_item(@recipe.id)

    assert_not result[:success]
    assert_equal "Not enough resources.", result[:error]
  end

  test "should craft item with exact resources" do
    service = CraftingService.new(@user)
    initial_item_count = @user.items.count
    initial_resource_amount = @user.user_resources.find_by(resource: @resource).amount

    result = service.craft_item(@recipe.id)

    assert result[:success]
    assert_equal initial_item_count + 1, @user.reload.items.count
    assert_equal initial_resource_amount - 1, @user.user_resources.find_by(resource: @resource).amount
  end

  test "should increment item quantity if user already has item" do
    service = CraftingService.new(@user)
    user_item = @user.user_items.create(item: @item, quantity: 1)
    initial_item_count = user_item.quantity
    initial_resource_amount = @user.user_resources.find_by(resource: @resource).amount

    result = service.craft_item(@recipe.id)

    assert result[:success]
    assert_equal initial_item_count + 1, user_item.reload.quantity
    assert_equal initial_resource_amount - 1, @user.user_resources.find_by(resource: @resource).amount
  end
end
