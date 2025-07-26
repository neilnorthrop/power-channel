# frozen_string_literal: true

class UserActionSerializer
  include JSONAPI::Serializer
  attributes :id, :last_performed_at, :user_id, :action_id, :level

  attribute :cooldown do |object|
    object.action.cooldown
  end

  belongs_to :action, serializer: ActionSerializer
end
