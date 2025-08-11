# frozen_string_literal: true

require "test_helper"

class CraftingServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @recipe = recipes(:lucky_charm_recipe)
    @item = items(:one)
    @gold = resources(:gold)
    @stone = resources(:stone)

    # Set user resources for crafting
    @user.user_resources.find_by(resource: @gold)&.update(amount: 10)
    @user.user_resources.find_or_create_by(resource: @stone)&.update(amount: 10)
    @user.user_items.destroy_all
  end

  test "should craft item and decrement resources" do
    service = CraftingService.new(@user)
    initial_gold_amount = @user.user_resources.find_by(resource: @gold).amount
    initial_stone_amount = @user.user_resources.find_by(resource: @stone).amount

    result = service.craft_item(@recipe.id)

    assert result[:success]
    assert_equal 1, @user.user_items.count
    assert_equal initial_gold_amount - 5, @user.user_resources.find_by(resource: @gold).amount
    assert_equal initial_stone_amount - 2, @user.user_resources.find_by(resource: @stone).amount
  end

  test "should not craft item if not enough resources" do
    service = CraftingService.new(@user)
    @user.user_resources.find_by(resource: @gold).update(amount: 0)
    result = service.craft_item(@recipe.id)

    assert_not result[:success]
    assert_equal "Not enough resources.", result[:error]
  end

  test "should increment item quantity if user already has item" do
    service = CraftingService.new(@user)
    user_item = @user.user_items.create(item: @item, quantity: 1)
    initial_quantity = user_item.quantity

    result = service.craft_item(@recipe.id)

    assert result[:success]
    assert_equal initial_quantity + 1, user_item.reload.quantity
  end
end
