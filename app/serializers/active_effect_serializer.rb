# frozen_string_literal: true

class ActiveEffectSerializer
  include JSONAPI::Serializer
  attributes :id, :expires_at

  attribute :name do |object|
    object.effect.name
  end

  attribute :description do |object|
    object.effect.description
  end
end
