# frozen_string_literal: true

class SkillService
  def initialize(user)
    @user = user
  end

  def unlock_skill(skill_id)
    skill = Skill.find(skill_id)
    if @user.skill_points >= skill.cost
      @user.skills << skill
      @user.decrement!(:skill_points, skill.cost)
      { success: true, message: "#{skill.name} unlocked successfully." }
    else
      { success: false, error: 'Not enough skill points.' }
    end
  end

  def apply_skills_to_action(action, cooldown, amount)
    @user.skills.each do |skill|
      cooldown, amount = send(skill.effect, action, cooldown, amount)
    end
    [cooldown, amount]
  end

  private

  def increase_gold_gain(action, cooldown, amount)
    amount *= 1.1 if action.resources.any? { |r| r.name == 'Gold Coins' } # Do not use a hardcoded string
    [cooldown, amount]
  end

  def decrease_wood_cooldown(action, cooldown, amount)
    cooldown *= 0.9 if action.resources.any? { |r| r.name == 'Wood' } # Do not use a hardcoded string
    [cooldown, amount]
  end

  def increase_stone_gain(action, cooldown, amount)
    amount *= 1.1 if action.resources.any? { |r| r.name == 'Stone' } # Do not use a hardcoded string
    [cooldown, amount]
  end
end
