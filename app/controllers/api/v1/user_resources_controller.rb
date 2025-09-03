# frozen_string_literal: true

class Api::V1::UserResourcesController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    user_resources = @current_user.user_resources.includes(:resource)
    render json: UserResourcesSerializer.new(user_resources).serializable_hash.to_json
  end
end
