# frozen_string_literal: true

module SkillEffects
  class DecreaseGainEffect < BaseEffect
    def self.apply(action, cooldown, amount, resource_name, multiplier)
      amount *= multiplier if action.resources.any? { |r| r.name == resource_name }
      [ cooldown, amount ]
    end
  end
end
