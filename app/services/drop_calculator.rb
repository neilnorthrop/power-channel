# frozen_string_literal: true

module DropCalculator
  module_function

  # Clamp chance at 100% after applying multiplier
  def effective_chance(chance, mult)
    [ (chance.to_f * mult.to_f), 1.0 ].min
  end

  # Roll a Bernoulli trial with given chance
  def roll?(chance)
    Kernel.rand < chance.to_f
  end

  # Compute base quantity prior to multipliers/skills.
  # If min/max provided, choose uniform integer in range and scale by level.
  # Otherwise, fall back to the provided default (or 1 if nil).
  def base_quantity(min, max, level, default)
    if !min.nil? && !max.nil?
      min_i = min.to_i
      max_i = max.to_i
      base = (min_i == max_i) ? min_i : Kernel.rand(min_i..max_i)
      base * level.to_i
    else
      # Preserve semantics: 0 is valid; only nil falls back to 1
      (default.nil? ? 1 : default.to_i)
    end
  end

  # Probabilistically quantize a fractional exact value to an integer.
  # Adds +1 with probability equal to the fractional part. Ensures a minimum
  # on success (default 1) when specified.
  def quantize_with_prob(exact, min_on_success: 1)
    exact_f = exact.to_f
    int = exact_f.floor
    frac = exact_f - int
    amount = int + (Kernel.rand < frac ? 1 : 0)

    if min_on_success
      min_val = min_on_success.to_i
      amount = min_val if amount < min_val
    end
    amount
  end
end
