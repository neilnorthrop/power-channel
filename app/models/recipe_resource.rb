class RecipeResource < ApplicationRecord
  belongs_to :recipe
  belongs_to :resource
end
