# frozen_string_literal: true

class Api::V1::ResourcesController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/resources
  # Retrieve a list of resources for the current user.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "name": "Wood",
  #     "description": "Basic building material.",
  #     "base_amount": 2.0
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of resources available in the world. For per-user amounts, use `GET /api/v1/user_resources`.
  # @example GET /api/v1/resources
  #   curl -X GET "https://example.com/api/v1/resources"
  def index
    resources = @current_user.resources
    render json: ResourceSerializer.new(resources).serializable_hash.to_json
  end
end
