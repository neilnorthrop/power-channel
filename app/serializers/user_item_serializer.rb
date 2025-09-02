# frozen_string_literal: true

class UserItemSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :item_id, :quantity
  belongs_to :item

  attribute :usable do |object|
    item = object.item
    # Usable if the item declares an effect or has associated Effect records
    item.effect.present? || item.effects.exists?
  end
end
