# frozen_string_literal: true

class Api::V1::ResourcesController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    resources = @current_user.resources
    render json: ResourceSerializer.new(resources).serializable_hash.to_json
  end
end
