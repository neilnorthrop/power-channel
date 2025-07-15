# frozen_string_literal: true

class Api::V1::AuthenticationController < Api::ApiController
  def create
    user = User.find_by(email: params[:email])
    if user&.valid_password?(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render json: { token: token }
    else
      render json: { error: 'unauthorized' }, status: :unauthorized
    end
  end
end
