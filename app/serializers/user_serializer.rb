# frozen_string_literal: true

class UserSerializer
  include JSONAPI::Serializer
  attributes :id, :email, :created_at, :level, :experience, :skill_points, :experimental_crafting
end
