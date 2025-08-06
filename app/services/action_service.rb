# frozen_string_literal: true

class ActionService
  def initialize(user)
    @user = user
  end

  def perform_action(action_id)
    action = Action.find(action_id)
    user_action = @user.user_actions.find_or_create_by(action: action)

    cooldown = action.cooldown
    amount = action.resource.base_amount

    skill_service = SkillService.new(@user)
    cooldown, amount = skill_service.apply_skills_to_action(action, cooldown, amount)

    if user_action.last_performed_at.nil? || Time.current > user_action.last_performed_at + cooldown.seconds
      user_resource = @user.user_resources.find_or_create_by(resource: action.resource)
      user_resource.increment!(:amount, amount)
      user_action.update(last_performed_at: Time.current)
      @user.gain_experience(10)
      @user.save
      { success: true, message: "#{action.name} performed successfully." }
    else
      { success: false, error: 'Action is on cooldown.' }
    end
  end
end
