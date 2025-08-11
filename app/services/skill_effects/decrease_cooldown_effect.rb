# frozen_string_literal: true

module SkillEffects
  class DecreaseCooldownEffect < BaseEffect
    def self.apply(action, cooldown, amount, resource_name, multiplier)
      cooldown *= multiplier if action.resources.any? { |r| r.name == resource_name }
      [ cooldown, amount ]
    end
  end
end
