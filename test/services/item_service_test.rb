# frozen_string_literal: true

require "test_helper"

class ItemServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)

    @luck_item = items(:one)
    @luck_item.effects.create!(
      name: "Luck Boost",
      target_attribute: "luck",
      modifier_type: "add",
      modifier_value: 1.0,
      duration: 60
    )

    @cooldown_item = items(:two)
    @cooldown_item.effects.create!(
      name: "Haste",
      target_attribute: "cooldown",
      modifier_type: "set",
      modifier_value: 0,
      duration: 0
    )
  end

  test "using luck item creates active effect" do
    service = ItemService.new(@user, @luck_item)
    assert_difference "ActiveEffect.count", 1 do
      service.use
    end
  end

  test "using cooldown item creates active effect" do
    service = ItemService.new(@user, @cooldown_item)
    assert_difference "ActiveEffect.count", 1 do
      service.use
    end
  end

  test "use calls increase_luck effect" do
    service = ItemService.new(@user, @luck_item)
    service.expects(:increase_luck)
    service.use
  end

  test "use calls reset_cooldown effect" do
    service = ItemService.new(@user, @cooldown_item)
    service.expects(:reset_cooldown)
    service.use
  end
end
