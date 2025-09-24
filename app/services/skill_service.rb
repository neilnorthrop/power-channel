# frozen_string_literal: true

class SkillService
  # Cache resolved effect classes keyed by full effect string.
  # Uses Concurrent::Map for thread-safe memoization when available.
  EFFECT_CLASS_CACHE = defined?(Concurrent::Map) ? Concurrent::Map.new : {}
  def initialize(user)
    @user = user
  end

  # Unlock a skill for the user if they have enough skill points to afford it.
  # Returns { success:, message: } or { success: false, error: }
  # Example return values:
  # { success: true, message: "Skill unlocked successfully." }
  # { success: false, error: "Skill already unlocked." }
  # { success: false, error: "Not enough skill points." }
  #
  # @param skill_id [Integer] the ID of the skill to unlock
  #
  # @return [Hash] result of the unlock attempt with success status and message or error details
  def unlock_skill(skill_id)
    skill = Skill.find(skill_id)
    return { success: false, error: "Skill already unlocked." } if @user.skills.include?(skill)
    if @user.skill_points >= skill.cost
      @user.skills << skill
      @user.decrement!(:skill_points, skill.cost)
      { success: true, message: "#{skill.name} unlocked successfully." }
    else
      { success: false, error: "Not enough skill points." }
    end
  end

  # Applies all of the user's skills to a given action, modifying its cooldown and amount.
  #
  # Iterates through each skill the user possesses, invoking the corresponding effect method
  # for each skill. Each effect method is expected to take the action, current cooldown, and
  # amount as arguments, and return the potentially modified cooldown and amount.
  #
  # @param action [Object] The action to which skills are being applied.
  # @param cooldown [Numeric] The initial cooldown value for the action.
  # @param amount [Numeric] The initial amount value for the action.
  #
  # @return [Array(Numeric, Numeric)] The modified cooldown and amount after all skills have been applied.
  def apply_skills_to_action(action, cooldown, amount)
    @user.skills.each do |skill|
      cooldown, amount = apply_skill_effect(skill, action, cooldown, amount)
    end
    [ cooldown, amount ]
  end

  private

  # Applies a single skill's effect to the action, modifying its cooldown and amount.
  # This method dynamically determines the appropriate effect class based on the skill's effect attribute,
  # and invokes the apply method on that class.
  # @param skill [Skill] The skill whose effect is to be applied.
  # @param action [Object] The action to which the skill effect is being applied.
  # @param cooldown [Numeric] The current cooldown value for the action.
  # @param amount [Numeric] The current amount value for the action.
  #
  # @return [Array(Numeric, Numeric)] The modified cooldown and amount after the skill effect has been applied.
  def apply_skill_effect(skill, action, cooldown, amount)
    effect = skill.effect.to_s
    user_id = @user&.id
    action_name = respond_to_action_name(action)

    Rails.logger.debug(
      "Applying skill effect" \
      + " user_id=#{user_id} skill_id=#{skill.id} effect=\"#{effect}\" action=\"#{action_name}\""
    )

    parsed = parse_effect(effect)
    unless parsed
      Rails.logger.warn(
        "Invalid skill effect format; skipping" \
        + " user_id=#{user_id} skill_id=#{skill.id} effect=\"#{effect}\""
      )
      return [ cooldown, amount ]
    end

    effect_class = resolve_effect_class(effect, parsed[:modification], parsed[:attribute])
    unless effect_class
      Rails.logger.warn(
        "Unresolvable skill effect class; skipping" \
        + " user_id=#{user_id} skill_id=#{skill.id} effect=\"#{effect}\""
      )
      return [ cooldown, amount ]
    end

    effect_class.apply(action, cooldown, amount, parsed[:resource].capitalize, skill.multiplier)
  rescue StandardError => e
    Rails.logger.error(
      "Error applying skill effect" \
      + " user_id=#{user_id} skill_id=#{skill.id} effect=\"#{effect}\" error=#{e.class}: #{e.message}"
    )
    [ cooldown, amount ]
  end

  # Parse effect string into parts. Returns a Hash or nil if invalid.
  def parse_effect(effect)
    # Expected: "<modification>_<resource>_<attribute>"
    # Examples: "increase_wood_gain", "decrease_stone_cooldown", "critical_all_gain"
    m = effect.match(/\A(?<modification>[a-z]+)_(?<resource>[a-z]+)_(?<attribute>[a-z]+)\z/)
    return nil unless m

    {
      modification: m[:modification],
      resource: m[:resource],
      attribute: m[:attribute]
    }
  end

  # Resolve and memoize the effect class for a given effect string.
  # Returns the class or nil if it cannot be resolved.
  def resolve_effect_class(effect, modification, attribute)
    cached = EFFECT_CLASS_CACHE[effect]
    return nil if cached == false
    return cached if cached

    effect_class_name = "SkillEffects::#{modification.camelize}#{attribute.camelize}Effect"
    Rails.logger.debug("Resolving effect class #{effect_class_name} for effect=\"#{effect}\"")

    klass = effect_class_name.safe_constantize
    # Cache result: class or false sentinel if missing
    EFFECT_CLASS_CACHE[effect] = klass || false
    klass
  end

  def respond_to_action_name(action)
    action.respond_to?(:name) ? action.name : action.class.name
  end
end
