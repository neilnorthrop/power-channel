# frozen_string_literal: true

module SkillEffects
  class CriticalGainEffect < BaseEffect
    def self.apply(action, cooldown, amount, _resource_name, multiplier)
      [ cooldown, amount * multiplier ]
    end
  end
end
