# frozen_string_literal: true

class YamlExporter
  def self.data_dir
    Rails.root.join("db", "data")
  end

  def self.export!(resource)
    case resource.to_s
    when "actions"      then export_actions!
    when "resources"    then export_resources!
    when "skills"       then export_skills!
    when "items"        then export_items!
    when "buildings"    then export_buildings!
    when "recipes"      then export_recipes!
    when "flags"        then export_flags!
    when "dismantle"    then export_dismantle!
    when "effects"      then export_effects!
    when "action_item_drops" then export_action_item_drops!
    else
      raise ArgumentError, "Unsupported export resource: #{resource}"
    end
  end

  def self.export_all!
    %w[actions resources skills items buildings recipes flags dismantle effects action_item_drops].each do |key|
      export!(key)
    end
  end

  def self.write_yaml!(basename, array)
    path = data_dir.join(basename)
    File.write(path, array.to_yaml)
    path
  end

  def self.export_actions!
    rows = Action.order(:order, :name).map do |a|
      {
        "name" => a.name,
        "description" => a.description,
        "cooldown" => a.respond_to?(:cooldown) ? a.cooldown : nil,
        "order" => a.order
      }.compact
    end
    write_yaml!("actions.yml", rows)
  end

  def self.export_resources!
    rows = Resource.order(:name).map do |r|
      {
        "name" => r.name,
        "description" => r.description,
        "base_amount" => r.base_amount,
        "currency" => r.respond_to?(:currency) ? r.currency : nil,
        "action_name" => r.action&.name,
        "min_amount" => r.respond_to?(:min_amount) ? r.min_amount : nil,
        "max_amount" => r.respond_to?(:max_amount) ? r.max_amount : nil,
        "drop_chance" => r.respond_to?(:drop_chance) ? r.drop_chance : nil
      }.compact
    end
    write_yaml!("resources.yml", rows)
  end

  def self.export_skills!
    rows = Skill.order(:name).map do |s|
      {
        "name" => s.name,
        "description" => s.description,
        "cost" => s.respond_to?(:cost) ? s.cost : nil,
        "effect" => s.effect,
        "multiplier" => s.respond_to?(:multiplier) ? s.multiplier : nil
      }.compact
    end
    write_yaml!("skills.yml", rows)
  end

  def self.export_items!
    rows = Item.order(:name).map do |i|
      {
        "name" => i.name,
        "description" => i.description,
        "effect" => i.effect,
        "drop_chance" => i.respond_to?(:drop_chance) ? i.drop_chance : nil
      }.compact
    end
    write_yaml!("items.yml", rows)
  end

  def self.export_buildings!
    rows = Building.order(:name).map do |b|
      {
        "name" => b.name,
        "description" => b.description,
        "level" => b.level,
        "effect" => b.effect
      }.compact
    end
    write_yaml!("buildings.yml", rows)
  end

  def self.export_recipes!
    rows = Recipe.includes(:item, :recipe_resources).order("items.name").map do |r|
      {
        "item" => r.item&.name,
        "quantity" => r.quantity || 1,
        "components" => r.recipe_resources.order(:component_type).map do |rr|
          comp = rr.component_type
          name = case comp
          when "Resource" then Resource.find_by(id: rr.component_id)&.name
          when "Item" then Item.find_by(id: rr.component_id)&.name
          else nil
          end
          {
            "type" => comp,
            "name" => name,
            "quantity" => rr.quantity,
            "group" => rr.group_key,
            "logic" => rr.logic
          }.compact
        end
      }.compact
    end
    write_yaml!("recipes.yml", rows)
  end

  def self.export_flags!
    rows = Flag.order(:slug).map do |f|
      base = {
        "slug" => f.slug,
        "name" => f.name,
        "description" => f.description
      }
      reqs = FlagRequirement.where(flag_id: f.id).map do |fr|
        name = case fr.requirement_type
        when "Flag" then Flag.find(fr.requirement_id)&.slug
        else Seeds::Loader.model_for(fr.requirement_type).find(fr.requirement_id)&.name
        end
        {
          "type" => fr.requirement_type,
          "name" => name,
          "quantity" => fr.quantity,
          "logic" => fr.logic
        }.compact
      end
      unlocks = Unlockable.where(flag_id: f.id).map do |u|
        name = case u.unlockable_type
        when "Action" then Action.find(u.unlockable_id)&.name
        when "Recipe" then (rec = Recipe.find(u.unlockable_id)) && Item.find(rec.item_id)&.name
        when "Item" then Item.find(u.unlockable_id)&.name
        when "Building" then Building.find(u.unlockable_id)&.name
        end
        { "type" => u.unlockable_type, "name" => name }.compact
      end
      base.merge("requirements" => reqs, "unlockables" => unlocks)
    end
    write_yaml!("flags.yml", rows)
  end

  def self.export_dismantle!
    rows = DismantleRule.where(subject_type: "Item").includes(:dismantle_yields).map do |dr|
      item_name = Item.find_by(id: dr.subject_id)&.name
      {
        "subject_type" => "Item",
        "subject_name" => item_name,
        "notes" => dr.notes,
        "yields" => dr.dismantle_yields.map do |dy|
          name = dy.component_type == "Resource" ? Resource.find_by(id: dy.component_id)&.name : Item.find_by(id: dy.component_id)&.name
          {
            "type" => dy.component_type,
            "name" => name,
            "quantity" => dy.quantity,
            "salvage_rate" => dy.salvage_rate&.to_f,
            "quality" => dy.quality
          }.compact
        end
      }.compact
    end
    write_yaml!("dismantle.yml", rows)
  end

  def self.export_effects!
    rows = Effect.order(:name).map do |e|
      effectable_name = case e.effectable_type
      when "Item" then Item.find_by(id: e.effectable_id)&.name
      when "Action" then Action.find_by(id: e.effectable_id)&.name
      end
      {
        "name" => e.name,
        "description" => e.description,
        "target_attribute" => e.target_attribute,
        "modifier_type" => e.modifier_type,
        "modifier_value" => e.modifier_value,
        "duration" => e.duration,
        "effectable_type" => e.effectable_type,
        "effectable_name" => effectable_name
      }.compact
    end
    write_yaml!("effects.yml", rows)
  end

  def self.export_action_item_drops!
    rows = ActionItemDrop.includes(:action, :item).map do |d|
      {
        "action" => d.action&.name,
        "item" => d.item&.name,
        "min_amount" => d.min_amount,
        "max_amount" => d.max_amount,
        "drop_chance" => d.drop_chance
      }.compact
    end
    write_yaml!("action_item_drops.yml", rows)
  end
end
