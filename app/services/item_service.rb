# frozen_string_literal: true

class ItemService
  def initialize(user, item)
    @user = user
    @item = item
  end

  def use
    send(@item.effect)
  end

  private

  def increase_luck
    # This is a placeholder. The actual implementation will depend on how
    # rare resource drops are calculated.
  end

  def reset_cooldown
    # This is a placeholder. The actual implementation will depend on how
    # action cooldowns are managed.
  end
end
