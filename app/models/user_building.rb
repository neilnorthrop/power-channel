class UserBuilding < ApplicationRecord
  belongs_to :user
  belongs_to :building
end
