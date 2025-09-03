# frozen_string_literal: true

class EventSerializer
  include JSONAPI::Serializer
  attributes :id, :level, :message, :created_at
end

