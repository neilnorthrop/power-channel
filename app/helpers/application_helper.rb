module ApplicationHelper
  # Wraps page content in the main Turbo Frame only for frame requests.
  # On full-page loads, it returns the content as-is (the layout provides the frame).
  def main_frame(id = "main", &block)
    if turbo_frame_request?
      turbo_frame_tag(id, &block)
    else
      capture(&block)
    end
  end

  def current_announcement
    @current_announcement ||= Announcement.active.published.order(Arel.sql("COALESCE(published_at, created_at) DESC")).first
  end
end
