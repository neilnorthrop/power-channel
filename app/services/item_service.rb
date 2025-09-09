# frozen_string_literal: true

class ItemService
  def initialize(user, item)
    @user = user
    @item = item
  end

  # Use the item, applying its effect if it has one.
  # Returns { success:, message: } or { success: false, error: }
  # Example return values:
  # { success: true, message: "Item used successfully." }
  # { success: false, error: "Item is not usable." }
  # { success: false, error: "Item cannot be used." }
  #
  # @return [Hash] result of the use attempt with success status and message or error details
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
