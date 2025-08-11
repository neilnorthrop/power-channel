# frozen_string_literal: true

module SkillEffects
  class BaseEffect
    def self.apply(action, cooldown, amount, resource_name)
      raise NotImplementedError, "Subclasses must implement a .apply method"
    end
  end
end
