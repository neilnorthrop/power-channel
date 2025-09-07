# frozen_string_literal: true

require "test_helper"

class DismantleServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @hatchet = items(:hatchet)
    @twine = items(:twine)
    @stone = resources(:stone)

    # Ensure inventory state
    @user.user_items.where(item: @hatchet).delete_all
    @user.user_items.where(item: @twine).delete_all
    @user.user_resources.where(resource: @stone).delete_all

    @user.user_items.create!(item: @hatchet, quantity: 1, quality: "normal")
    # dismantle rules/yields are provided by fixtures: hatchet_rule -> twine (1, 1.0), stone (5, 0.6)
  end

  test "dismantles item and grants outputs" do
    service = DismantleService.new(@user)
    result = service.dismantle_item(@hatchet.id)

    assert result[:success], result.inspect

    # Hatchet decremented
    assert_nil @user.user_items.find_by(item: @hatchet)

    # Twine +1
    twine_row = @user.user_items.find_by(item: @twine)
    assert_equal 1, twine_row.quantity
    assert_equal "normal", twine_row.quality

    # Stone floor(5 * 0.6) = 3
    stone_row = @user.user_resources.find_by(resource: @stone)
    assert_equal 3, stone_row.amount
  end

  test "fails if item not in inventory" do
    @user.user_items.where(item: @hatchet).delete_all
    service = DismantleService.new(@user)
    result = service.dismantle_item(@hatchet.id)
    assert_not result[:success]
    assert_match /not found/i, result[:error]
  end

  test "fails if no rule exists" do
    # Ensure twine is in inventory so the failure is due to missing rule
    @user.user_items.create!(item: @twine, quantity: 1, quality: "normal")
    service = DismantleService.new(@user)
    result = service.dismantle_item(@twine.id)
    assert_not result[:success]
    assert_match /cannot be dismantled/i, result[:error]
  end

  test "fails if all yields compute to zero" do
    # Create a zero-yield rule for twine
    rule = DismantleRule.create!(subject_type: "Item", subject_id: @twine.id)
    DismantleYield.create!(dismantle_rule: rule, component_type: "Resource", component_id: @stone.id, quantity: 1, salvage_rate: 0.0)
    @user.user_items.create!(item: @twine, quantity: 1, quality: "normal")

    service = DismantleService.new(@user)
    result = service.dismantle_item(@twine.id)
    assert_not result[:success]
    assert_match /No salvageable output/i, result[:error]
  end
end
