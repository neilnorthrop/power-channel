# frozen_string_literal: true

class BuildingSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :level, :effect
end
