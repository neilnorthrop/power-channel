# frozen_string_literal: true

class SkillService
  def initialize(user)
    @user = user
  end

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
  # @return [Array(Numeric, Numeric)] The modified cooldown and amount after all skills have been applied.
  def apply_skills_to_action(action, cooldown, amount)
    @user.skills.each do |skill|
      cooldown, amount = send(skill.effect, action, cooldown, amount)
    end
    [ cooldown, amount ]
  end

  private

  def method_missing(method_name, *args)
    modification, action_name, attributes = method_name.to_s.split("_", 3)
    action, cooldown, amount = args

    change = if modification == "increase"
                        1.1
    elsif modification == "decrease"
                        0.9
    end

    if attributes == "gain"
      amount *= change if action.resources.any? { |r| r.name == action_name.capitalize }
    elsif attributes == "cooldown"
      cooldown *= change if action.resources.any? { |r| r.name == action_name.capitalize }
    end
    [ cooldown, amount ]
  end

  # def increase_gold_gain(action, cooldown, amount)
  #   amount *= 1.1 if action.resources.any? { |r| r.name == "Gold Coins" } # Do not use a hardcoded string
  #   [ cooldown, amount ]
  # end

  # def decrease_wood_cooldown(action, cooldown, amount)
  #   cooldown *= 0.9 if action.resources.any? { |r| r.name == "Wood" } # Do not use a hardcoded string
  #   [ cooldown, amount ]
  # end

  # def increase_stone_gain(action, cooldown, amount)
  #   amount *= 1.1 if action.resources.any? { |r| r.name == "Stone" } # Do not use a hardcoded string
  #   [ cooldown, amount ]
  # end
end
