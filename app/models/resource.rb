class Resource < ApplicationRecord
  belongs_to :action, optional: true
  has_many :user_resources
  has_many :users, through: :user_resources
  has_many :recipe_resources
  has_many :recipes, through: :recipe_resources
end
