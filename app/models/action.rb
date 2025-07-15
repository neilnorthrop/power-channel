class Action < ApplicationRecord
  belongs_to :resource
  has_many :user_actions
  has_many :users, through: :user_actions
end
