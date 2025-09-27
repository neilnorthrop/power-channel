# frozen_string_literal: true

require "test_helper"

class ActionItemDropTest < ActiveSupport::TestCase
  setup do
    @action = actions(:gather_taxes)
    @item = items(:one)
  end

  test "drop_chance must be within 0..1" do
    drop = ActionItemDrop.new(action: @action, item: @item, drop_chance: 1.2)

    assert_not drop.valid?
    assert_includes drop.errors[:drop_chance], "must be less than or equal to 1"
  end

  test "min_amount cannot exceed max_amount" do
    drop = ActionItemDrop.new(action: @action, item: @item, drop_chance: 0.5, min_amount: 5, max_amount: 2)

    assert_not drop.valid?
    assert_includes drop.errors[:min_amount], "cannot be greater than max_amount"
  end
end
