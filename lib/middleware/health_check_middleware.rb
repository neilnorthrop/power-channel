# frozen_string_literal: true

# A tiny Rack middleware that responds very early in the stack for
# liveness (/healthz) and readiness (/readyz) checks.
#
# - /healthz returns 200 immediately if the app can serve requests.
# - /readyz additionally attempts a lightweight DB query.
#   If it fails, it returns 503 so your load balancer can drain the pod/instance.
#
# This avoids booting controllers, sessions, or CSRF, and keeps the
# endpoint stable even if routing is misconfigured during deploys.
class HealthCheckMiddleware
  OK = [200, { "Content-Type" => "text/plain" }, ["ok"]].freeze
  SERVICE_UNAVAILABLE = [503, { "Content-Type" => "text/plain" }, ["unhealthy"]].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"]
    method = env["REQUEST_METHOD"]
    if (path == "/healthz" || path == "/readyz") && (method == "GET" || method == "HEAD")
      return OK if path == "/healthz"
      begin
        # Cheap DB readiness probe
        if defined?(ActiveRecord)
          ActiveRecord::Base.connection.execute("SELECT 1")
        end
        OK
      rescue StandardError
        SERVICE_UNAVAILABLE
      end
    else
      @app.call(env)
    end
  end
end

