# frozen_string_literal: true

class Api::V1::EventsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  # GET /api/v1/events
  # Retrieve a list of events for the current user, filtered by optional parameters such as level, since, and before timestamps.
  # Example return value:
  # [
  #   {
  #     "id": 1,
  #     "user_id": 1,
  #     "level": "info",
  #     "message": "User logged in.",
  #     "created_at": "2024-06-01T12:00:00Z"
  #   },
  #   ...
  # ]
  # @return [JSON] a JSON array of events for the current user, filtered by the specified parameters
  # @example GET /api/v1/events?level=info&since=2024-06-01T00:00:00Z&before=2024-06-02T00:00:00Z&limit=100
  #   curl -X GET "https://example.com/api/v1/events?level=info&since=2024-06-01T00:00:00Z&before=2024-06-02T00:00:00Z&limit=100"
  def index
    limit = params[:limit].to_i
    limit = 50 if limit <= 0 || limit > 200
    since = params[:since].present? ? (Time.iso8601(params[:since]) rescue 24.hours.ago) : 24.hours.ago
    before = params[:before].present? ? (Time.iso8601(params[:before]) rescue nil) : nil

    scope = @current_user.events.where("created_at >= ?", since)
    if params[:level].present?
      level = params[:level].to_s
      scope = scope.where(level: level) if Event::LEVELS.include?(level)
    end
    scope = scope.where("created_at < ?", before) if before
    events = scope.order(created_at: :asc).limit(limit)
    render json: EventSerializer.new(events).serializable_hash.to_json
  end
end
