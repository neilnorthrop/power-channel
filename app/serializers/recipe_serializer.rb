# frozen_string_literal: true

class RecipeSerializer
  include JSONAPI::Serializer
  attributes :id, :quantity, :item_id
  has_many :recipe_resources
  belongs_to :item, serializer: ItemSerializer
end
