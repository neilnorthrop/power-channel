# frozen_string_literal: true

class Api::V1::ActionsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    user_actions = @current_user.user_actions.includes(:action)
    # Bulk gate check to avoid N+1
    action_ids = user_actions.map(&:action_id)
    gates = Unlockable.where(unlockable_type: "Action", unlockable_id: action_ids)
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_user_actions = user_actions.select do |ua|
      (flag_id = gates[ua.action_id]).nil? || user_flag_ids.include?(flag_id)
    end
    # Stable ordering by Action.order then name to prevent UI jumping
    visible_user_actions.sort_by! { |ua| [ ua.action.order || 1000, ua.action.name.to_s ] }.reverse!
    # Prefetch requirement names for flags used by these gated actions
    flag_ids = gates.values.compact.uniq
    requirement_names = RequirementNameLookup.for_flag_ids(flag_ids)

    options = { include: [ :action ], params: { current_user: @current_user, gates: { "Action" => gates }, user_flag_ids: user_flag_ids, requirement_names: requirement_names } }
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
