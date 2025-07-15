# frozen_string_literal: true

class ActionSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :cooldown, :resource_id
end
