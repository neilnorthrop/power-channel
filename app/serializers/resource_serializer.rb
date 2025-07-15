# frozen_string_literal: true

class ResourceSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :base_amount
end
