# frozen_string_literal: true

class Api::V1::SkillsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    skills = Skill.all
    render json: SkillSerializer.new(skills).serializable_hash.to_json
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
