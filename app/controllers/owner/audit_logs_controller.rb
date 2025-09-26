# frozen_string_literal: true

module Owner
  class AuditLogsController < BaseController
    def index
      scope = OwnerAuditLog.includes(:actor, :target_user).order(created_at: :desc)
      @q = params[:q].to_s.strip
      @actor = params[:actor].to_s.strip
      @target = params[:target].to_s.strip
      @action = params[:action_filter].to_s.strip

      scope = scope.where("action ILIKE ?", "%#{@q}%") if @q.present?
      scope = scope.joins(:actor).where("users.email ILIKE ?", "%#{@actor}%") if @actor.present?
      if @target.present?
        scope = scope.joins("LEFT JOIN users targets ON targets.id = owner_audit_logs.target_user_id")
                     .where("targets.email ILIKE ?", "%#{@target}%")
      end
      scope = scope.where(action: @action) if @action.present?

      @page = [params[:page].to_i, 1].max
      @per = [[params[:per].to_i, 1].max, 50].min
      @per = 20 if params[:per].blank?
      @total_count = scope.count
      @total_pages = (@total_count / @per.to_f).ceil
      @logs = scope.offset((@page - 1) * @per).limit(@per)
    end
  end
end

