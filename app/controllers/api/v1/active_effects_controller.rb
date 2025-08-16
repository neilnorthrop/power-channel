# frozen_string_literal: true

class Api::V1::ActiveEffectsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    active_effects = @current_user.active_effects
    render json: ActiveEffectSerializer.new(active_effects).serializable_hash.to_json
  end
end
