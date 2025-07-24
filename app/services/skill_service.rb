# frozen_string_literal: true

class SkillService
  def initialize(user)
    @user = user
  end

  # Applies all skills of the user to a given action, modifying its cooldown and amount.
  #
  # Iterates through each skill the user possesses, invoking the corresponding effect method
  # for each skill. Each effect method is expected to take the action, cooldown, and amount
  # as arguments, and return potentially modified cooldown and amount values.
  #
  # @param action [Object] The action to which skills are applied.
  # @param cooldown [Numeric] The initial cooldown value for the action.
  # @param amount [Numeric] The initial amount value for the action.
  # @return [Array(Numeric, Numeric)] The modified cooldown and amount after all skills are applied.
  def apply_skills_to_action(action, cooldown, amount)
    @user.skills.each do |skill|
      cooldown, amount = send(skill.effect, action, cooldown, amount)
    end
    [cooldown, amount]
  end

  private

  def increase_gold_gain(action, cooldown, amount)
    amount *= 1.1 if action.resource.name == 'Gold'
    [cooldown, amount]
  end

  def decrease_wood_cooldown(action, cooldown, amount)
    cooldown *= 0.9 if action.resource.name == 'Wood'
    [cooldown, amount]
  end

  def increase_stone_gain(action, cooldown, amount)
    amount *= 1.1 if action.resource.name == 'Stone'
    [cooldown, amount]
  end
end
