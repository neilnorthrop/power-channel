# frozen_string_literal: true

require "test_helper"

class DismantleRuleTest < ActiveSupport::TestCase
  test "valid fixture" do
    rule = dismantle_rules(:hatchet_rule)
    assert rule.valid?
    assert_equal "Item", rule.subject_type
    assert_equal items(:hatchet).id, rule.subject_id
    assert rule.dismantle_yields.any?
  end

  test "subject_type must be Item only for now" do
    rule = DismantleRule.new(subject_type: "Building", subject_id: 1)
    assert_not rule.valid?
  end
end
