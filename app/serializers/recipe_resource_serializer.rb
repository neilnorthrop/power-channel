# frozen_string_literal: true

class RecipeResourceSerializer
  include JSONAPI::Serializer
  attributes :id, :quantity, :recipe_id, :component_type, :component_id

  attribute :component_name do |rr|
    case rr.component_type
    when 'Resource'
      Resource.find_by(id: rr.component_id)&.name
    when 'Item'
      Item.find_by(id: rr.component_id)&.name
    else
      nil
    end
  end
end
