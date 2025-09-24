# frozen_string_literal: true

require "test_helper"

class DropCalculatorTest < ActiveSupport::TestCase
  test "effective_chance multiplies and clamps at 1.0" do
    assert_in_delta 0.5, DropCalculator.effective_chance(0.5, 1.0), 1e-9
    assert_in_delta 0.6, DropCalculator.effective_chance(0.3, 2.0), 1e-9
    assert_in_delta 1.0, DropCalculator.effective_chance(0.8, 2.0), 1e-9
    assert_in_delta 0.0, DropCalculator.effective_chance(nil, 2.0), 1e-9
  end

  test "roll? respects chance using Kernel.rand" do
    Kernel.stubs(:rand).returns(0.4)
    assert DropCalculator.roll?(0.5)
    Kernel.stubs(:rand).returns(0.5)
    assert_not DropCalculator.roll?(0.5)
  end

  test "base_quantity uses min..max times level when provided" do
    # When min == max, no RNG
    assert_equal 9, DropCalculator.base_quantity(3, 3, 3, 1)

    # When min != max, use RNG from Kernel.rand
    Kernel.stubs(:rand).returns(4) # pick 4 from 3..5
    assert_equal 12, DropCalculator.base_quantity(3, 5, 3, 1)
  end

  test "base_quantity falls back to default or 1" do
    assert_equal 7, DropCalculator.base_quantity(nil, nil, 2, 7)
    assert_equal 0, DropCalculator.base_quantity(nil, nil, 2, 0)
    assert_equal 1, DropCalculator.base_quantity(nil, nil, 2, nil)
  end

  test "quantize_with_prob performs probabilistic rounding and enforces min" do
    # exact = 3.3 → base 3, frac 0.3
    Kernel.stubs(:rand).returns(0.1)
    assert_equal 4, DropCalculator.quantize_with_prob(3.3)

    Kernel.stubs(:rand).returns(0.9)
    assert_equal 3, DropCalculator.quantize_with_prob(3.3)

    # Enforce min_on_success
    Kernel.stubs(:rand).returns(0.9)
    assert_equal 1, DropCalculator.quantize_with_prob(0.2, min_on_success: 1)
  end
end
