# frozen_string_literal: true

class UserItemSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :item_id
  belongs_to :item
end
