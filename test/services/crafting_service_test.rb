# frozen_string_literal: true

require "test_helper"

class CraftingServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @recipe = recipes(:lucky_charm_recipe)
    @item = items(:one)
    @gold = resources(:gold)
    @stone = resources(:stone)
    @hatchet_recipe = recipes(:hatchet_recipe)
    @twine = items(:twine)
    @wood = resources(:wood)

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

class CraftingServiceItemComponentTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @recipe = recipes(:hatchet_recipe)
    @hatchet = items(:hatchet)
    @twine = items(:twine)
    @wood = resources(:wood)

    # Ensure user has enough components: wood resource and twine items
    @user.user_resources.find_or_create_by(resource: @wood).update(amount: 20)
    @user.user_items.find_or_create_by(item: @twine).update(quantity: 5)
    @user.user_items.where(item: @hatchet).destroy_all
  end

  test "crafts when item component present and decrements both" do
    service = CraftingService.new(@user)
    wood_before = @user.user_resources.find_by(resource: @wood).amount
    twine_before = @user.user_items.find_by(item: @twine).quantity

    result = service.craft_item(@recipe.id)

    assert result[:success]
    assert_equal wood_before - 10, @user.user_resources.find_by(resource: @wood).reload.amount
    assert_equal twine_before - 2, @user.user_items.find_by(item: @twine).reload.quantity
    assert_equal 1, @user.user_items.find_by(item: @hatchet).quantity
  end

  test "fails when missing item component" do
    @user.user_items.find_by(item: @twine).update(quantity: 0)
    service = CraftingService.new(@user)
    result = service.craft_item(@recipe.id)
    assert_not result[:success]
    assert_equal "Not enough resources.", result[:error]
  end
end
