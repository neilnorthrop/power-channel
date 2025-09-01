# frozen_string_literal: true

# JWT helper using a secret loaded from Rails configuration.
#
# The secret is configured in `config/application.rb` as:
#   `config.jwt_secret = ENV["JWT_SECRET"]`
# and should be provided via an environment variable (e.g., from a
# shell-exported `.env` file in development or your hosting provider's
# env settings in production). See README for setup instructions.

class JsonWebToken
  SECRET_KEY = Rails.application.config.jwt_secret

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new decoded
  end
end
