# frozen_string_literal: true

class UserResourcesSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :amount, :resource_id

  attribute :name do |object|
    object.resource.name
  end

  belongs_to :resource, serializer: ResourceSerializer
end
