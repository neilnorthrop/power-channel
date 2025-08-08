# frozen_string_literal: true

require "test_helper"

class EffectTest < ActiveSupport::TestCase
  def setup
    @effect = effects(:one)
  end

  test "should be valid" do
    assert @effect.valid?
  end
end
