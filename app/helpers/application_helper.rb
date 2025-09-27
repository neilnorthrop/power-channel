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

  # Default list columns for Owner::Content views per resource key
  def default_list_columns(key)
    case key.to_s
    when "actions" then %i[name cooldown order]
    when "resources" then %i[name action_name min_amount max_amount drop_chance currency]
    when "items" then %i[name effect drop_chance]
    when "skills" then %i[name effect cost multiplier]
    when "buildings" then %i[name level effect]
    when "recipes" then %i[item_name quantity components_count]
    when "flags" then %i[slug name]
    when "effects" then %i[name effectable_type effectable_name target_attribute modifier_type modifier_value duration]
    when "dismantle" then %i[subject_type subject_name yields_count]
    when "action_item_drops" then %i[action_name item_name min_amount max_amount drop_chance]
    else %i[id]
    end
  end

  # Friendly column labels per resource for Content header
  def header_label_for(resource_key, col)
    if resource_key.to_s == 'actions' && col.to_s == 'order'
      'Display Order'
    else
      col.to_s.titleize
    end
  end
end
