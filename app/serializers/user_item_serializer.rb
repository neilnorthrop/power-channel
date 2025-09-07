# frozen_string_literal: true

class UserItemSerializer
  include JSONAPI::Serializer
  attributes :id, :user_id, :item_id, :quantity, :quality
  belongs_to :item

  attribute :usable do |object, params|
    item = object.item
    effect_name = item.effect.to_s
    usable_by_method = effect_name.present? && ItemService.instance_methods(false).include?(effect_name.to_sym)
    return true if usable_by_method

    # Optionally use precomputed set to avoid N+1
    items_with_effects = params && params[:items_with_effects]
    if items_with_effects
      items_with_effects.include?(item.id)
    else
      item.effects.exists?
    end
  end
end
