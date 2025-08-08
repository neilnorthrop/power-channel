class Effect < ApplicationRecord
  belongs_to :effectable, polymorphic: true
  has_many :active_effects
end
