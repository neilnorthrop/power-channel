# frozen_string_literal: true

class Api::V1::UsersController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def show
    render json: UserSerializer.new(@current_user).serializable_hash.to_json
  end
end
