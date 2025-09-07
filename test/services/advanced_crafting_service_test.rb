# frozen_string_literal: true

require "test_helper"

class AdvancedCraftingServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @recipe = recipes(:lucky_charm_recipe)
    @gold = resources(:gold)
    @stone = resources(:stone)
    @user.user_resources.find_by(resource: @gold)&.update(amount: 10)
    @user.user_resources.find_or_create_by(resource: @stone)&.update(amount: 10)
    @user.user_items.destroy_all
  end

  test "behaves like base service for now" do
    service = AdvancedCraftingService.new(@user)
    result = service.craft_item(@recipe.id)
    assert result[:success]
    assert_equal 1, @user.user_items.count
  end
end

