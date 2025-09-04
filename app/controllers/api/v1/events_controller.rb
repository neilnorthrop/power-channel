# frozen_string_literal: true

class Api::V1::EventsController < Api::ApiController
  include Authenticable
  before_action :authenticate_request

  def index
    limit = params[:limit].to_i
    limit = 50 if limit <= 0 || limit > 200
    since = params[:since].present? ? (Time.iso8601(params[:since]) rescue 24.hours.ago) : 24.hours.ago
    before = params[:before].present? ? (Time.iso8601(params[:before]) rescue nil) : nil

    scope = @current_user.events.where('created_at >= ?', since)
    if params[:level].present?
      level = params[:level].to_s
      scope = scope.where(level: level) if Event::LEVELS.include?(level)
    end
    scope = scope.where('created_at < ?', before) if before
    events = scope.order(created_at: :asc).limit(limit)
    render json: EventSerializer.new(events).serializable_hash.to_json
  end
end

