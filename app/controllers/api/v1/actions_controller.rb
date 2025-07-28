# frozen_string_literal: true

class Api::V1::ActionsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    user_actions = @current_user.user_actions
    options = { include: [:action] }
    render json: UserActionSerializer.new(user_actions, options).serializable_hash.to_json
  end

  def create
    action = Action.find(params[:action_id])
    user_action = @current_user.user_actions.find_or_create_by(action: action)

    cooldown = action.cooldown
    amount = action.resource.base_amount

    skill_service = SkillService.new(@current_user)
    cooldown, amount = skill_service.apply_skills_to_action(action, cooldown, amount)

    if user_action.last_performed_at.nil? || Time.current > user_action.last_performed_at + cooldown.seconds
      user_resource = @current_user.user_resources.find_or_create_by(resource: action.resource)
      user_resource.increment!(:amount, amount)
      user_action.update(last_performed_at: Time.current)
      @current_user.gain_experience(10)
      serialized_user = UserSerializer.new(@current_user).serializable_hash
      serialized_user[:message] = "#{action.name} performed successfully."
      render json: serialized_user.to_json
    else
      render json: { error: 'Action is on cooldown.' }, status: :unprocessable_entity
    end
  end

  def update
    user_action = @current_user.user_actions.find(params[:id])
    if user_action.upgrade
      render json: { message: "#{user_action.action.name} upgraded successfully." }
    else
      render json: { error: 'Failed to upgrade action.' }, status: :unprocessable_entity
    end
  end
end
