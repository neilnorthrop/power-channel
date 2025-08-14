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

    assert_equal [active], ActiveEffect.active.to_a
  end
end
