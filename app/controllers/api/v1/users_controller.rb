# frozen_string_literal: true

class Api::V1::UsersController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/users/me
  # Retrieve the current user's details.
  # Example return value:
  # {
  #   "id": 1,
  #   "username": "player_one",
  #   "email": "test@example.com",
  #   "created_at": "2024-06-01T12:00:00Z",
  #   "updated_at": "2024-06-01T12:00:00Z"
  # }
  # @return [JSON] a JSON object containing the current user's details
  # @example GET /api/v1/users/me
  #   curl -X GET "https://example.com/api/v1/users/me"
  def show
    render json: UserSerializer.new(@current_user).serializable_hash.to_json
  end
end
