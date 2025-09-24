module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token]
      raise JWT::DecodeError, "missing token" if token.blank?
      decoded_token = JsonWebToken.decode(token)
      if (current_user = User.find(decoded_token[:user_id]))
        current_user
      else
        reject_unauthorized_connection
      end
    rescue ActiveRecord::RecordNotFound, JWT::DecodeError
      reject_unauthorized_connection
    end
  end
end
