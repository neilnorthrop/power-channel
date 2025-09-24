class Skill < ApplicationRecord
  # Effect format: "<modification>_<resource>_<attribute>"
  # Examples: "increase_wood_gain", "decrease_stone_cooldown", "critical_all_gain"
  EFFECT_FORMAT = /
    \A
    (increase|decrease|critical) # modification
    _
    [a-z]+                       # resource (e.g., wood, taxes, stone, all)
    _
    (gain|cooldown)              # attribute
    \z
  /x.freeze

  validates :effect, presence: true, format: { with: EFFECT_FORMAT }
end
