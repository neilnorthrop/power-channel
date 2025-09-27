# frozen_string_literal: true

class YamlExporter
  RESOURCE_KEYS = %w[actions resources skills items buildings recipes flags dismantle effects action_item_drops].freeze

  class << self
    def data_dir
      Rails.root.join("db", "data")
    end

    def export!(resource)
      _, rows = build_payload(resource)
      bundle = load_bundle
      bundle["core"][resource.to_s] = rows
      write_bundle(bundle)
    end

    def preview!(resource)
      build_payload(resource)
    end

    def export_all!
      bundle = load_bundle
      bundle["core"] = {}
      resources.each do |key|
        _, rows = build_payload(key)
        bundle["core"][key] = rows
      end
      write_bundle(bundle)
    end

    def resources
      RESOURCE_KEYS
    end

    private

    def aggregate_path
      data_dir.join("aether.yml")
    end

    def load_bundle
      if aggregate_path.exist?
        data = YAML.safe_load(File.read(aggregate_path), aliases: true) || {}
        data["core"] ||= {}
        data["packs"] ||= {}
        data
      else
        { "core" => {}, "packs" => {} }
      end
    end

    def write_bundle(bundle)
      File.write(aggregate_path, bundle.to_yaml)
      aggregate_path
    end

    def build_payload(resource)
      case resource.to_s
      when "actions" then ["actions.yml", rows_for_actions]
      when "resources" then ["resources.yml", rows_for_resources]
      when "skills" then ["skills.yml", rows_for_skills]
      when "items" then ["items.yml", rows_for_items]
      when "buildings" then ["buildings.yml", rows_for_buildings]
      when "recipes" then ["recipes.yml", rows_for_recipes]
      when "flags" then ["flags.yml", rows_for_flags]
      when "dismantle" then ["dismantle.yml", rows_for_dismantle]
      when "effects" then ["effects.yml", rows_for_effects]
      when "action_item_drops" then ["action_item_drops.yml", rows_for_action_item_drops]
      else
        raise ArgumentError, "Unsupported export resource: #{resource}"
      end
    end

    def rows_for_actions
      Action.order(:order, :name).map do |a|
        {
          "name" => a.name,
          "description" => a.description,
          "cooldown" => a.respond_to?(:cooldown) ? a.cooldown : nil,
          "order" => a.order
        }.compact
      end
    end

    def rows_for_resources
      Resource.order(:name).map do |r|
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
    end

    def rows_for_skills
      Skill.order(:name).map do |s|
        {
          "name" => s.name,
          "description" => s.description,
          "cost" => s.respond_to?(:cost) ? s.cost : nil,
          "effect" => s.effect,
          "multiplier" => s.respond_to?(:multiplier) ? s.multiplier : nil
        }.compact
      end
    end

    def rows_for_items
      Item.order(:name).map do |i|
        {
          "name" => i.name,
          "description" => i.description,
          "effect" => i.effect,
          "drop_chance" => i.respond_to?(:drop_chance) ? i.drop_chance : nil
        }.compact
      end
    end

    def rows_for_buildings
      Building.order(:name).map do |b|
        {
          "name" => b.name,
          "description" => b.description,
          "level" => b.level,
          "effect" => b.effect
        }.compact
      end
    end

    def rows_for_recipes
      Recipe.includes(:item, :recipe_resources).order("items.name").map do |r|
        {
          "item" => r.item&.name,
          "quantity" => r.quantity || 1,
          "components" => r.recipe_resources.order(:component_type).map do |rr|
            comp = rr.component_type
            name = case comp
                   when "Resource" then Resource.find_by(id: rr.component_id)&.name
                   when "Item" then Item.find_by(id: rr.component_id)&.name
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
    end

    def rows_for_flags
      Flag.order(:slug).map do |f|
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
    end

    def rows_for_dismantle
      DismantleRule.where(subject_type: "Item").includes(:dismantle_yields).map do |dr|
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
    end

    def rows_for_effects
      Effect.order(:name).map do |e|
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
    end

    def rows_for_action_item_drops
      ActionItemDrop.includes(:action, :item).map do |d|
        {
          "action" => d.action&.name,
          "item" => d.item&.name,
          "min_amount" => d.min_amount,
          "max_amount" => d.max_amount,
          "drop_chance" => d.drop_chance
        }.compact
      end
    end
  end
end
