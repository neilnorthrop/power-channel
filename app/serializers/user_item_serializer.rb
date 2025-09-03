# frozen_string_literal: true

class UserItemSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :item_id, :quantity
  belongs_to :item

  attribute :usable do |object|
    item = object.item
    # Usable if:
    # - the item.effect maps to a method implemented in ItemService, or
    # - the item has associated Effect records
    effect_name = item.effect.to_s
    usable_by_method = effect_name.present? && ItemService.instance_methods(false).include?(effect_name.to_sym)
    usable_by_assoc = item.effects.exists?
    usable_by_method || usable_by_assoc
  end
end
