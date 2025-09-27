# frozen_string_literal: true

# JWT helper using a secret loaded from Rails configuration.
#
# The secret is configured in `config/application.rb` as:
#   `config.jwt_secret = ENV["JWT_SECRET"]`
# and should be provided via an environment variable (e.g., from a
# shell-exported `.env` file in development or your hosting provider's
# env settings in production). See README for setup instructions.

class JsonWebToken
  def self.encode(payload, exp = 24.hours.from_now, algorithm = "HS256")
    payload[:exp] = exp.to_i
    key = secret_key!
    JWT.encode(payload, key, algorithm)
  end

  def self.decode(token)
    key = secret_key!
    # Verify signature and expiration, and constrain accepted algorithm.
    decoded = JWT.decode(token, key, true, { algorithm: "HS256", verify_expiration: true })[0]
    HashWithIndifferentAccess.new decoded
  end

  # Returns the configured secret key or raises in production if missing.
  def self.secret_key!
    key = Rails.application.config.jwt_secret
    if key.blank?
      if Rails.env.production?
        raise "JWT_SECRET is not configured. Set ENV['JWT_SECRET']."
      else
        Rails.logger.warn("JWT_SECRET is not configured; using empty secret in #{Rails.env}.")
      end
    end
    key
  end
  private_class_method :secret_key!
end
