class Item < ApplicationRecord
  has_many :user_items
  has_many :users, through: :user_items
  has_many :recipe_resources, as: :component
  has_many :recipes, through: :recipe_resources
  has_one :recipe
  has_many :effects, as: :effectable, dependent: :destroy
end
