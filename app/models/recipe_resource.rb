class RecipeResource < ApplicationRecord
  belongs_to :recipe
  belongs_to :component, polymorphic: true

  validates :quantity, numericality: { greater_than: 0 }
end
