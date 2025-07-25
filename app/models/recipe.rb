class Recipe < ApplicationRecord
  belongs_to :item
  has_many :recipe_resources
  has_many :resources, through: :recipe_resources
end
