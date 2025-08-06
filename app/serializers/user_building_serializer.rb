# frozen_string_literal: true

class UserBuildingSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :building_id, :level
  belongs_to :building
end
