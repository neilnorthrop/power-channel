# frozen_string_literal: true

module Owner
  class DashboardController < BaseController
    def index
      @users_count = User.count
      @owners_count = User.role_owner.count
      @mods_count = User.role_mod.count
      @supports_count = User.role_support.count
      @recent_users = User.order(created_at: :desc).limit(10)
      @recent_audits = OwnerAuditLog.order(created_at: :desc).limit(10)
      @recent_announcements = Announcement.order(created_at: :desc).limit(3)
      @latest_db_report = DbValidationReport.order(created_at: :desc).first
      @queue_health = QueueHealthService.snapshot
    end
  end
end
