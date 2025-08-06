# frozen_string_literal: true

class UserSkillSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :skill_id
  belongs_to :skill
end
