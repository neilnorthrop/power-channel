# frozen_string_literal: true

module Owner::SeedsHelper
  def suggestion_for(section, message)
    case section.to_s
    when "actions"
      link_to("Open Actions", owner_content_index_path(resource: "actions"))
    when "resources"
      link_to("Open Resources", owner_content_index_path(resource: "resources"))
    when "skills"
      link_to("Open Skills", owner_content_index_path(resource: "skills"))
    when "items"
      link_to("Open Items", owner_content_index_path(resource: "items"))
    when "buildings"
      link_to("Open Buildings", owner_content_index_path(resource: "buildings"))
    when "effects"
      link_to("Open Effects", owner_effects_path)
    when "recipes"
      link_to("Open Recipes Editor", owner_recipes_path)
    when "flags"
      link_to("Open Flags Editor", owner_flags_path)
    when "dismantle"
      link_to("Open Dismantle Editor", owner_dismantles_path)
    when "action_item_drops"
      link_to("Open Item Drops Editor", owner_action_item_drops_path)
    else
      "-"
    end
  end

  def apply_suggestion_link(section, name)
    case section.to_s
    when "actions"
      link_to(name, owner_content_index_path(resource: "actions", q: name))
    when "resources"
      link_to(name, owner_content_index_path(resource: "resources", q: name))
    when "skills"
      link_to(name, owner_content_index_path(resource: "skills", q: name))
    when "items"
      link_to(name, owner_content_index_path(resource: "items", q: name))
    when "buildings"
      link_to(name, owner_content_index_path(resource: "buildings", q: name))
    when "effects"
      link_to(name, owner_effects_path(q: name))
    when "recipes"
      link_to(name, owner_recipes_path(q: name))
    when "flags"
      link_to(name, owner_flags_path(q: name))
    when "dismantle"
      link_to(name, owner_dismantles_path(q: name))
    when "action_item_drops"
      # Try to find an action by name close to suggestion
      if (action = Action.where("LOWER(name) = ?", name.downcase).first)
        link_to(name, owner_action_item_drops_path(action_id: action.id))
      else
        name
      end
    else
      name
    end
  end

  def create_link_for(section, name = nil)
    case section.to_s
    when "actions", "resources", "items", "skills", "buildings"
      link_to("Create", new_owner_content_path(resource: section, name: name))
    when "recipes"
      link_to("Create", new_owner_recipe_path)
    when "flags"
      link_to("Create", new_owner_flag_path(slug: name, name: name&.titleize))
    when "effects"
      link_to("Create", new_owner_effect_path)
    when "dismantle"
      link_to("Create", new_owner_dismantle_path(item: name))
    when "action_item_drops"
      link_to("Open Editor", owner_action_item_drops_path(q: name))
    else
      "-"
    end
  end
end
