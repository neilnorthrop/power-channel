# frozen_string_literal: true

class Api::V1::SkillsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    skills = Skill.all
    render json: SkillSerializer.new(skills).serializable_hash.to_json
  end

  def create
    skill = Skill.find(params[:skill_id])
    if @current_user.skill_points >= skill.cost
      @current_user.skills << skill
      @current_user.decrement!(:skill_points, skill.cost)
      render json: { message: "#{skill.name} unlocked successfully." }
    else
      render json: { error: 'Not enough skill points.' }, status: :unprocessable_entity
    end
  end
end
