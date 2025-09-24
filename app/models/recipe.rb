class Recipe < ApplicationRecord
  belongs_to :item
  has_many :recipe_resources
  # Convenience scopes for specific component types
  has_many :resource_components, -> { where(component_type: "Resource") }, class_name: "RecipeResource"
  has_many :item_components,     -> { where(component_type: "Item") },     class_name: "RecipeResource"
end
