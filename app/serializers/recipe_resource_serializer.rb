# frozen_string_literal: true

class RecipeResourceSerializer
  include JSONAPI::Serializer
  attributes :id, :quantity, :recipe_id, :component_type, :component_id, :group_key, :logic

  attribute :component_name do |rr, params|
    names = params && params[:component_names]
    if names
      (names[rr.component_type] || {})[rr.component_id]
    else
      case rr.component_type
      when "Resource"
        Resource.find_by(id: rr.component_id)&.name
      when "Item"
        Item.find_by(id: rr.component_id)&.name
      else
        nil
      end
    end
  end
end
