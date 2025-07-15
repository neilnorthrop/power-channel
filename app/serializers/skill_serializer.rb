# frozen_string_literal: true

class SkillSerializer
  include JSONAPI::Serializer
  attributes :id, :name, :description, :cost, :effect
end
