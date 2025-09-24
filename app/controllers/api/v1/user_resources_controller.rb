# frozen_string_literal: true

class Api::V1::UserResourcesController < Api::ApiController
  include Authenticable

  # GET /api/v1/user_resources
  # Retrieve a list of user resources for the current user, including associated resource details.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "user_id": 1,
  #     "resource_id": 1,
  #     "amount": 100,
  #     "resource": {
  #       "id": 1,
  #       "name": "Wood",
  #       "description": "Basic building material."
  #     }
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of user resources with associated resource details for the current user
  # @example GET /api/v1/user_resources
  #   curl -X GET "https://example.com/api/v1/user_resources"
  def index
    user_resources = @current_user.user_resources.includes(:resource)
    render json: UserResourcesSerializer.new(user_resources).serializable_hash.to_json
  end
end
