# frozen_string_literal: true

require "test_helper"

class ActionResourceDropTest < ActiveSupport::TestCase
  setup do
    @action = actions(:gather_taxes)
    @resource = resources(:gold)
  end

  test "drop_chance must be within 0..1" do
    drop = ActionResourceDrop.new(action: @action, resource: @resource, drop_chance: -0.1)

    assert_not drop.valid?
    assert_includes drop.errors[:drop_chance], "must be greater than or equal to 0"
  end

  test "min_amount cannot exceed max_amount" do
    drop = ActionResourceDrop.new(action: @action, resource: @resource, drop_chance: 0.5, min_amount: 10, max_amount: 5)

    assert_not drop.valid?
    assert_includes drop.errors[:min_amount], "cannot be greater than max_amount"
  end
end
