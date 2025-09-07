# frozen_string_literal: true

require "test_helper"

class DismantleYieldTest < ActiveSupport::TestCase
  test "valid fixtures" do
    y1 = dismantle_yields(:hatchet_rule_twine)
    y2 = dismantle_yields(:hatchet_rule_stone)
    assert y1.valid?
    assert y2.valid?
    assert_includes %w[Item Resource], y1.component_type
    assert y1.quantity.positive?
    assert y1.salvage_rate.between?(0.0, 1.0)
  end

  test "invalid salvage_rate outside 0..1" do
    dy = DismantleYield.new(dismantle_rule: dismantle_rules(:hatchet_rule), component_type: "Resource", component_id: resources(:stone).id, quantity: 1, salvage_rate: 1.5)
    assert_not dy.valid?
  end
end
