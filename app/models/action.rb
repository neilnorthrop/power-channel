class Action < ApplicationRecord
  has_many :resources
  has_many :user_actions
  has_many :users, through: :user_actions
  has_many :effects, as: :effectable, dependent: :destroy
end
