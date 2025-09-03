# frozen_string_literal: true

class Api::V1::SkillsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    skills = Skill.all
    # Bulk gate check to avoid N+1
    gates = Unlockable.where(unlockable_type: 'Skill', unlockable_id: skills.pluck(:id))
                      .pluck(:unlockable_id, :flag_id).to_h
    user_flag_ids = @current_user.user_flags.pluck(:flag_id).to_set
    visible_skill_ids = skills.map(&:id).select { |id| (flag_id = gates[id]).nil? || user_flag_ids.include?(flag_id) }
    visible_skills = skills.select { |s| visible_skill_ids.include?(s.id) }
    options = { params: { current_user: @current_user, gates: { 'Skill' => gates }, user_flag_ids: user_flag_ids } }
    render json: SkillSerializer.new(visible_skills, options).serializable_hash.to_json
  end

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
