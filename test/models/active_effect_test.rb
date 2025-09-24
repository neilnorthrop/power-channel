# frozen_string_literal: true

require "test_helper"

class ActiveEffectTest < ActiveSupport::TestCase
  def setup
    @active_effect = active_effects(:one)
  end

  test "should be valid" do
    assert @active_effect.valid?
  end

  test "should be active" do
    @active_effect.update(expires_at: 1.hour.from_now)
    assert_includes ActiveEffect.active, @active_effect
  end

  test "should not be active" do
    @active_effect.update(expires_at: 1.hour.ago)
    assert_not_includes ActiveEffect.active, @active_effect
  end

  test "active scope returns only non-expired effects" do
    active = active_effects(:one)
    expired = active_effects(:two)
    active.update(expires_at: 1.hour.from_now)
    expired.update(expires_at: 1.hour.ago)

    assert_equal [ active ], ActiveEffect.active.to_a
  end

  test "luck_sum_for includes global and matching scoped luck" do
    user = users(:one)
    # Global luck (target_attribute NULL)
    global = Effect.create!(
      name: "Global Luck",
      description: "",
      target_attribute: nil,
      modifier_type: "luck",
      modifier_value: 0.1,
      duration: 60,
      effectable: items(:one)
    )
    # Scoped to action:gather_wood
    scoped = Effect.create!(
      name: "Wood Luck",
      description: "",
      target_attribute: "action:gather_wood",
      modifier_type: "luck",
      modifier_value: 0.1,
      duration: 60,
      effectable: items(:one)
    )
    ActiveEffect.create!(user: user, effect: global, expires_at: 1.hour.from_now)
    ActiveEffect.create!(user: user, effect: scoped, expires_at: 1.hour.from_now)

    total = ActiveEffect.luck_sum_for(user, "action:gather_wood")
    assert_in_delta 0.2, total, 1e-6
  end

  test "luck_sum_for excludes non-matching scoped luck but includes global" do
    user = users(:one)
    # Global luck
    global = Effect.create!(
      name: "Global Luck",
      description: "",
      target_attribute: nil,
      modifier_type: "luck",
      modifier_value: 0.1,
      duration: 60,
      effectable: items(:one)
    )
    # Scoped to different action
    scoped_other = Effect.create!(
      name: "Stone Luck",
      description: "",
      target_attribute: "action:gather_stone",
      modifier_type: "luck",
      modifier_value: 0.15,
      duration: 60,
      effectable: items(:one)
    )
    ActiveEffect.create!(user: user, effect: global, expires_at: 1.hour.from_now)
    ActiveEffect.create!(user: user, effect: scoped_other, expires_at: 1.hour.from_now)

    total = ActiveEffect.luck_sum_for(user, "action:gather_wood")
    assert_in_delta 0.1, total, 1e-6
  end
end
