# frozen_string_literal: true

class RecipeResourceSerializer
  include JSONAPI::Serializer
  attributes :id, :quantity, :recipe_id, :resource_id
  belongs_to :resource
end
