# frozen_string_literal: true

class Api::V1::UsersController < Api::ApiController
  include Authenticable

  # GET /api/v1/user
  # Retrieve the current user's details.
  # Example return value:
  # {
  #   "id": 1,
  #   "email": "test@example.com",
  #   "level": 1,
  #   "experience": 0,
  #   "skill_points": 0,
  #   "experimental_crafting": false
  # }
  # @return [JSON] a JSON object containing the current user's details
  # @example GET /api/v1/user
  #   curl -X GET "https://example.com/api/v1/user"
  def show
    render json: UserSerializer.new(@current_user).serializable_hash.to_json
  end
end
