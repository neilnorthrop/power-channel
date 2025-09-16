# frozen_string_literal: true

class SkillService
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
    Rails.logger.debug("Applying skill effect for skill ID #{skill.id} and user ID #{@user.id}")
    modification, resource_name, attribute = skill.effect.split("_", 3)
    Rails.logger.debug("Skill effect details: modification=#{modification}, resource_name=#{resource_name}, attribute=#{attribute}")
    effect_class_name = "SkillEffects::#{modification.camelize}#{attribute.camelize}Effect"

    Rails.logger.debug("Looking for effect class: #{effect_class_name}")
    effect_class = effect_class_name.constantize
    effect_class.apply(action, cooldown, amount, resource_name.capitalize, skill.multiplier)
  rescue NameError
    # Handle cases where the effect class doesn't exist
    [ cooldown, amount ]
  rescue StandardError => e
    # Log or handle other potential errors gracefully
    Rails.logger.error("Error applying skill effect: #{e.message} for skill ID #{skill.id} and user ID #{@user.id}")
    [ cooldown, amount ]
  end
end
