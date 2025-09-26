# frozen_string_literal: true

module Owner
  class AnnouncementsController < BaseController
    def index
      @announcements = Announcement.order(created_at: :desc)
    end

    def new
      @announcement = Announcement.new(active: true)
    end

    def create
      @announcement = Announcement.new(announcement_params)
      if @announcement.save
        OwnerAuditLog.create!(actor: current_actor, action: "announcement.create", metadata: { id: @announcement.id, title: @announcement.title })
        redirect_to owner_announcements_path, notice: "Announcement created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @announcement = Announcement.find(params[:id])
    end

    def update
      @announcement = Announcement.find(params[:id])
      if @announcement.update(announcement_params)
        OwnerAuditLog.create!(actor: current_actor, action: "announcement.update", metadata: { id: @announcement.id })
        redirect_to owner_announcements_path, notice: "Announcement updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle
      @announcement = Announcement.find(params[:id])
      @announcement.update!(active: !@announcement.active)
      OwnerAuditLog.create!(actor: current_actor, action: "announcement.toggle", metadata: { id: @announcement.id, active: @announcement.active })
      redirect_to owner_announcements_path, notice: "Announcement #{@announcement.active ? 'activated' : 'deactivated'}."
    end

    def publish_now
      @announcement = Announcement.find(params[:id])
      @announcement.update!(active: true, published_at: Time.current)
      OwnerAuditLog.create!(actor: current_actor, action: "announcement.publish_now", metadata: { id: @announcement.id })
      redirect_to owner_announcements_path, notice: "Announcement published now."
    end

    def publish_in
      @announcement = Announcement.find(params[:id])
      hours = params[:hours].to_i
      hours = 1 if hours <= 0
      time = Time.current + hours.hours
      @announcement.update!(active: true, published_at: time)
      OwnerAuditLog.create!(actor: current_actor, action: "announcement.publish_in", metadata: { id: @announcement.id, hours: hours, at: time })
      redirect_to owner_announcements_path, notice: "Announcement scheduled in #{hours}h and activated."
    end

    private

    def announcement_params
      params.require(:announcement).permit(:title, :body, :active, :published_at)
    end
  end
end
