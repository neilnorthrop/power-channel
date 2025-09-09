# frozen_string_literal: true

class Api::V1::ActionsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/actions
  # Returns a list of actions available to the current user, filtered by unlockable gates and sorted by action order and name.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "user_id": 1,
  #     "action_id": 1,
  #     "level": 1,
  #     "action": {
  #       "id": 1,
  #       "name": "Gather Wood",
  #       "description": "Collect wood from the forest.",
  #       "order": 1
  #     }
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of user actions with associated action details, filtered and sorted for the current user
  # @example GET /api/v1/actions
  #   curl -X GET "https://example.com/api/v1/actions
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

  # POST /api/v1/actions
  # Perform an action for the current user, checking for cooldowns and unlockable requirements.
  # Example return value:
  # {
  #   "id": 1,
  #   "user_id": 1,
  #   "action_id": 1,
  #   "level": 1,
  #   "action": {
  #     "id": 1,
  #     "name": "Gather Wood",
  #     "description": "Collect wood from the forest.",
  #     "order": 1
  #   },
  #   "message": "10 coins collected from taxes!"
  # }
  # @return [JSON] a JSON object representing the user action performed, including any success message or error details
  # @example POST /api/v1/actions
  #   curl -X POST "https://example.com/api/v1/actions" -d '{"action_id":1}'
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

  # PATCH /api/v1/actions/:id
  # Upgrade a user action for the current user, increasing its level and potentially unlocking new features or benefits associated with that action.
  # Example return value:
  # {
  #   "message": "Gather Wood upgraded successfully."
  # }
  # @return [JSON] a JSON object indicating the success of the upgrade operation or any error details
  # @example PATCH /api/v1/actions/1
  #   curl -X PATCH "https://example.com/api/v1/actions/1"
  def update
    user_action = @current_user.user_actions.find(params[:id])
    if user_action.upgrade
      render json: { message: "#{user_action.action.name} upgraded successfully." }
    else
      render json: { error: "Failed to upgrade action." }, status: :unprocessable_entity
    end
  end
end
