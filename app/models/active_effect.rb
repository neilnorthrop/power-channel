class ActiveEffect < ApplicationRecord
  belongs_to :user
  belongs_to :effect

  scope :active, -> { where("expires_at > ?", Time.current) }
end
