# frozen_string_literal: true

class ActionService
  def initialize(user)
    @user = user
  end

  def perform_action(action_id)
    action = Action.find_by(id: action_id)
    return { success: false, error: "Action not found." } unless action

    user_action = @user.user_actions.find_or_create_by(action: action)

    cooldown = action.cooldown

    if user_action.last_performed_at.nil? || Time.current > user_action.last_performed_at + cooldown.seconds
      action.resources.each do |resource|
        if rand.round(4) <= resource.drop_chance
          amount = resource.base_amount
          skill_service = SkillService.new(@user)
          cooldown, amount = skill_service.apply_skills_to_action(action, cooldown, amount)
          user_resource = @user.user_resources.find_or_create_by(resource: resource)
          user_resource.increment!(:amount, amount)
        end
      end
      user_action.update(last_performed_at: Time.current)
      @user.gain_experience(10)
      @user.save
      UserUpdatesChannel.broadcast_to(@user, { type: "user_action_update", data: UserActionSerializer.new(user_action, include: [ :action ]).serializable_hash })
      UserUpdatesChannel.broadcast_to(@user, { type: "user_resource_update", data: UserResourcesSerializer.new(@user.user_resources).serializable_hash })
      { success: true, message: "#{action.name} performed successfully." }
    else
      { success: false, error: "Action is on cooldown." }
    end
  end
end
