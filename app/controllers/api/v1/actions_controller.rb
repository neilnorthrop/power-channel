# frozen_string_literal: true

class Api::V1::ActionsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    user_actions = @current_user.user_actions
    # Hide gated actions the user hasn't unlocked yet
    visible_user_actions = user_actions.select do |ua|
      if (gate = Unlockable.find_by(unlockable_type: 'Action', unlockable_id: ua.action_id))
        @current_user.user_flags.exists?(flag_id: gate.flag_id)
      else
        true
      end
    end
    options = { include: [ :action ], params: { current_user: @current_user } }
    render json: UserActionSerializer.new(visible_user_actions, options).serializable_hash.to_json
  end

  def create
    action_service = ActionService.new(@current_user)
    result = action_service.perform_action(params[:action_id])

    if result[:success]
      serialized_user = UserSerializer.new(@current_user).serializable_hash
      serialized_user[:message] = result[:message]
      render json: serialized_user.to_json
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def update
    user_action = @current_user.user_actions.find(params[:id])
    if user_action.upgrade
      render json: { message: "#{user_action.action.name} upgraded successfully." }
    else
      render json: { error: "Failed to upgrade action." }, status: :unprocessable_entity
    end
  end
end
