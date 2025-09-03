# frozen_string_literal: true

class ItemService
  def initialize(user, item)
    @user = user
    @item = item
  end

  def use
    effect_method = @item.effect.to_s
    return { success: false, error: "Item is not usable." } if effect_method.blank?
    unless respond_to?(effect_method, true)
      return { success: false, error: "Item cannot be used." }
    end
    send(effect_method)
  end

  private

  def increase_luck
    apply_item_effect
  end

  def reset_cooldown
    apply_item_effect
  end

  def apply_item_effect
    effect = @item.effects.first
    return { success: false, error: "No effect associated with item." } unless effect

    EffectService.new(@user, effect).apply
    { success: true, message: "#{effect.name} applied." }
  end
end
