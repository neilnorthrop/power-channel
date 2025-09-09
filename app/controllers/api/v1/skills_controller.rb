# frozen_string_literal: true

class Api::V1::SkillsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/skills
  # Retrieve a list of skills for the current user, filtered by unlockable requirements and user flags.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "name": "Woodcutting",
  #     "description": "Skill for cutting wood.",
  #     "level": 1
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of skills for the current user, filtered by unlockable requirements and user flags
  # @example GET /api/v1/skills
  #   curl -X GET "https://example.com/api/v1/skills"
  def index
    skills = Skill.all
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: "Skill", unlockable_id: skills.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_skill_ids = skills.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_skills = skills.select { |s| visible_skill_ids.include?(s.id) }
    flag_ids = gates.values.compact.uniq
    requirement_names = RequirementNameLookup.for_flag_ids(flag_ids)
    options = { params: { current_user: @current_user, gates: { "Skill" => gates }, user_flag_ids: user_flag_ids, requirement_names: requirement_names } }
    render json: SkillSerializer.new(visible_skills, options).serializable_hash.to_json
  end

  # POST /api/v1/skills
  # Unlock a new skill for the current user, checking for unlockable requirements and user flags.
  # Example return value:
  # {
  #   "message": "Skill unlocked successfully."
  # }
  # @return [JSON] a JSON object indicating the success of the unlock operation or any error details
  # @example POST /api/v1/skills
  #   curl -X POST "https://example.com/api/v1/skills" -d '{"skill_id": 1}'
  def create
    skill_service = SkillService.new(@current_user)
    result = skill_service.unlock_skill(params[:skill_id])
    if result[:success]
      UserUpdatesChannel.broadcast_to(@current_user, { type: "user_skill_update", data: UserSkillSerializer.new(@current_user.user_skills).serializable_hash })
      UserUpdatesChannel.broadcast_to(@current_user, { type: "user_update", data: UserSerializer.new(@current_user).serializable_hash })
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end
end
