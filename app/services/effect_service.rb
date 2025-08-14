# frozen_string_literal: true

class EffectService
  def initialize(user, effect)
    @user = user
    @effect = effect
  end

  def apply
    ActiveEffect.create!(
      user: @user,
      effect: @effect,
      expires_at: Time.current + @effect.duration.seconds
    )
  end
end
