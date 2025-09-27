require_relative "boot"
require_relative '../lib/middleware/health_check_middleware'

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AetherForge
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # JWT signing secret: read from environment variable.
    # Configure `JWT_SECRET` in your environment (see README for `.env` usage).
    # There is intentionally no fallback to Rails credentials to keep one
    # source of truth across environments.
    config.jwt_secret = ENV["JWT_SECRET"]

    # Cooldown period (in seconds) between performing the same action.
    # Default is 60 seconds in production, 5 seconds in development for easier testing.
    config.action_cooldown = Rails.env.development? ? 5 : 60 # seconds

    # Register the health check middleware at the very top of the stack so
    # it responds even if routing or other middlewares are misbehaving.
    config.middleware.insert_before 0, HealthCheckMiddleware
  end
end
