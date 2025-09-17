# frozen_string_literal: true

require "yaml"

  module Seeds
    module Loader
      module_function

      def data_dir
        Rails.root.join("db", "data")
      end

    def available_packs
      packs_root = data_dir.join("packs")
      return [] unless Dir.exist?(packs_root)
      Dir.children(packs_root).select { |c| File.directory?(packs_root.join(c)) }.sort
    end

    def selected_pack_names
      packs_env = ENV["PACKS"]&.strip
      exclude_env = ENV["EXCLUDE"]&.strip

      return [] if exclude_env&.downcase == "all"

      names = []
      if packs_env.present?
        if packs_env.downcase == "all"
          names = available_packs
        else
          names = packs_env.split(",").map(&:strip).reject(&:empty?)
        end
      else
        names = [] # Backward compatible: only load packs when PACKS is set
      end

      if exclude_env.present?
        excludes = exclude_env.split(",").map { |x| x.strip.downcase }.reject(&:empty?)
        names = names.reject { |n| excludes.include?(n.downcase) }
      end
      names
    end

    def pack_dirs
      selected_pack_names.map { |name| data_dir.join("packs", name) }
    end

    def load_yaml(basename)
      rows = []
      # Base file first
      base = data_dir.join(basename)
      rows.concat YAML.safe_load(File.read(base), permitted_classes: [ Symbol ], aliases: true) if File.exist?(base)

      # Then overlay packs in listed order
      pack_dirs.each do |dir|
        path = dir.join(basename)
        next unless File.exist?(path)
        pack_rows = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ], aliases: true)
        rows.concat(pack_rows) if pack_rows
      end
      rows || []
    rescue StandardError => e
      STDOUT.puts("Error loading YAML file '#{basename}': '#{base}' #{e.message}")
      STDOUT.puts(e.backtrace.join("\n"))
      raise e
    end

    def apply!(dry_run: false, prune: false, logger: STDOUT)
      log = ->(msg) { logger.puts(msg) if logger }

      # Actions (with order auto-assignment and pack-aware offsets)
      action_rows = []
      # core first
      core_path = data_dir.join("actions.yml")
      if File.exist?(core_path)
        (YAML.safe_load(File.read(core_path), permitted_classes: [ Symbol ], aliases: true) || []).each do |row|
          action_rows << [ row, "core" ]
        end
      end
      # then packs
      selected_pack_names.each do |pack|
        path = data_dir.join("packs", pack, "actions.yml")
        next unless File.exist?(path)
        (YAML.safe_load(File.read(path), permitted_classes: [ Symbol ], aliases: true) || []).each do |row|
          action_rows << [ row, pack ]
        end
      end

      action_rows.each do |(attrs, source)|
        attrs = attrs.dup
        # Apply global cooldown if not set
        #
        # Note: this will overwrite any existing cooldown values in the DB if the action is re-seeded.
        # This is intentional to ensure consistency across all actions.
        # If you need per-action cooldowns, consider setting them explicitly in the YAML files.
        #
        # The cooldown value is read from Rails config, which is set in application.rb
        # This allows easy adjustment via environment (1 second in dev, 60 seconds in prod).
        # If you want to disable this behavior, you can comment out this block.
        # Alternatively, you can set a specific cooldown value in the YAML file to override the default.
        # If you want to remove cooldowns entirely, set cooldown: 0 in the YAML file.
        # This approach ensures that all actions have a sensible default cooldown unless explicitly overridden.
        # This is particularly useful in development environments where rapid testing is needed.
        if attrs.key?("cooldown") || attrs.key?(:cooldown)
          attrs["cooldown"] = Rails.application.config.action_cooldown.to_i
        end
        # Auto-assign order if missing: allocate blocks per source to avoid manual hunting
        if attrs["order"].nil? && attrs[:order].nil?
          # Respect existing DB order if present
          existing = Action.find_by(name: attrs["name"] || attrs[:name]) unless dry_run
          if existing && existing.order
            attrs["order"] = existing.order
          else
            # Segment size and base by source
            segment_size = 10_000
            base_offset = if source == "core"
                            0
            else
                            # stable offset based on pack position (1-based)
                            (selected_pack_names.index(source).to_i + 1) * segment_size
            end
            current_max = dry_run ? base_offset : (Action.where(order: base_offset..(base_offset + segment_size - 1)).maximum(:order) || base_offset)
            attrs["order"] = current_max + 10
          end
        end
        upsert(Action, by: :name, attrs: attrs, dry_run: dry_run)
      end
      log.call("Seeded actions: #{action_rows.size} (packs: #{selected_pack_names.join(', ')})")

      # Resources (resolve action by name)
      resources = load_yaml("resources.yml")
      resources.each do |attrs|
        log.call("Processing resource: '#{resources}'") if attrs.nil?
        action_name = attrs&.delete("action_name") || attrs&.delete(:action_name)
        next if dry_run && action_name && Action.find_by(name: action_name).nil?
        rec = find_or_init(Resource, by: { name: attrs["name"] || attrs[:name] })
        rec.assign_attributes(attrs)
        rec.action = Action.find_by(name: action_name) if action_name
        save!(rec, dry_run)
      end
      log.call("Seeded resources: #{resources.size}")

      # Skills
      skills = load_yaml("skills.yml")
      skills.each { |attrs| upsert(Skill, by: :name, attrs: attrs, dry_run: dry_run) }
      log.call("Seeded skills: #{skills.size}")

      # Items
      items = load_yaml("items.yml")
      items.each { |attrs| upsert(Item, by: :name, attrs: attrs, dry_run: dry_run) }
      log.call("Seeded items: #{items.size}")

      # Effects (support Item/Action effectables)
      effects = load_yaml("effects.yml")
      effects.each do |attrs|
        type = attrs.fetch("effectable_type")
        effectable_name = attrs.fetch("effectable_name")
        model = model_for(type)
        next if dry_run && model.find_by(name: effectable_name).nil?
        target = model.find_by(name: effectable_name)
        raise "Unknown effectable #{type}: '#{effectable_name}'" if target.nil? && !dry_run
        next if target.nil?
        rec = Effect.find_or_initialize_by(effectable: target, name: attrs["name"]) do |e|
          e.description = attrs["description"]
          e.target_attribute = attrs["target_attribute"]
          e.modifier_type = attrs["modifier_type"]
          e.modifier_value = attrs["modifier_value"]
          e.duration = attrs["duration"]
        end
        rec.assign_attributes(
          description: attrs["description"],
          target_attribute: attrs["target_attribute"],
          modifier_type: attrs["modifier_type"],
          modifier_value: attrs["modifier_value"],
          duration: attrs["duration"]
        )
        save!(rec, dry_run)
      end
      log.call("Seeded effects: #{effects.size}")

      # Buildings
      buildings = load_yaml("buildings.yml")
      buildings.each { |attrs| upsert(Building, by: :name, attrs: attrs, dry_run: dry_run) }
      log.call("Seeded buildings: #{buildings.size}")

      # Recipes and components
      recipes = load_yaml("recipes.yml")
      recipes.each do |row|
        item_name = row.fetch("item") { row[:item] }
        quantity  = row.fetch("quantity", 1)
        item = Item.find_by(name: item_name)
        if item.nil?
          raise "Unknown recipe item '#{item_name}'" unless dry_run
          next
        end
        recipe = find_or_init(Recipe, by: { item_id: item.id })
        recipe.quantity = quantity
        save!(recipe, dry_run)

        keep_ids = []
        Array(row["components"] || row[:components]).each do |comp|
          type = comp.fetch("type") { comp[:type] }
          name = comp.fetch("name") { comp[:name] }
          qty  = comp.fetch("quantity") { comp[:quantity] }
          group_key = comp["group"] || comp[:group]
          logic = (comp["logic"] || comp[:logic] || "AND").to_s.upcase

          case type
          when "Resource"
            model = Resource
            target = model.find_by(name: name)
          when "Item"
            model = Item
            target = model.find_by(name: name)
          else
            raise "Unsupported component type '#{type}' for recipe '#{item_name}'"
          end

          if target.nil?
            raise "Unknown component #{type}:'#{name}' in recipe '#{item_name}'" unless dry_run
            next
          end

          rr = RecipeResource.find_or_initialize_by(recipe_id: recipe.id, component_type: type, component_id: target.id)
          rr.quantity = qty
          rr.group_key = group_key
          rr.logic = logic
          save!(rr, dry_run)
          keep_ids << [ type, target.id ]
        end

        if prune && !dry_run
          RecipeResource.where(recipe_id: recipe.id).where.not(component_type: keep_ids.map(&:first), component_id: keep_ids.map(&:last)).delete_all
        end
      end
      log.call("Seeded recipes: #{recipes.size}")

      # Flags, requirements, unlockables
      flags = load_yaml("flags.yml")
      flags.each do |f|
        base = f.slice("slug", "name", "description")
        flag = upsert(Flag, by: :slug, attrs: base, dry_run: dry_run)

        Array(f["requirements"]).each do |req|
          type = req["type"] # Resource, Item, Skill, Building, Flag
          name = req["name"]
          quantity = req["quantity"] || 1
          logic = req["logic"] || "AND"
          model = model_for(type)
          next if dry_run && model.find_by(name: name).nil?
          target = type == "Flag" ? Flag.find_by(slug: name) : model.find_by(name: name)
          raise "Unknown requirement #{type}: '#{name}' for flag '#{flag.slug}'" if target.nil? && !dry_run
          next if target.nil?
          fr = FlagRequirement.find_or_initialize_by(flag_id: flag.id, requirement_type: type, requirement_id: target.id)
          fr.quantity = quantity
          fr.logic    = logic
          save!(fr, dry_run)
        end

        Array(f["unlockables"]).each do |u|
          type = u["type"] # Action, Recipe, Item, Building
          name = u["name"]
          case type
          when "Action"
            target = Action.find_by(name: name)
          when "Recipe"
            item = Item.find_by(name: name)
            target = item && Recipe.find_by(item_id: item.id)
          when "Item"
            target = Item.find_by(name: name)
          when "Building"
            target = Building.find_by(name: name)
          else
            raise "Unsupported unlockable type '#{type}'"
          end
          if target.nil?
            raise "Unknown unlockable #{type}: '#{name}' for flag '#{flag.slug}'" unless dry_run
            next
          end
          save!(Unlockable.find_or_initialize_by(flag_id: flag.id, unlockable: target), dry_run)
        end
      end
      log.call("Seeded flags: #{flags.size}")

      # Action Item Drops
      action_item_drops = load_yaml("action_item_drops.yml")
      action_item_drops.each do |row|
        action_name = row.fetch("action") { row[:action] }
        item_name   = row.fetch("item") { row[:item] }
        min_amount  = row["min_amount"] || row[:min_amount]
        max_amount  = row["max_amount"] || row[:max_amount]
        drop_chance = row.fetch("drop_chance") { row[:drop_chance] }
        action = Action.find_by(name: action_name)
        item   = Item.find_by(name: item_name)
        if action.nil? || item.nil?
          raise "Unknown action '#{action_name}' or item '#{item_name}' for action_item_drop" unless dry_run
          next
        end
        rec = ActionItemDrop.find_or_initialize_by(action: action, item: item)
        rec.min_amount = min_amount
        rec.max_amount = max_amount
        rec.drop_chance = drop_chance
        save!(rec, dry_run)
      end
      log.call("Seeded action item drops: #{action_item_drops.size}")

      # Dismantle rules (items only for now)
      dismantles = load_yaml("dismantle.yml")
      dismantles.each do |row|
        subject_type = row.fetch("subject_type", "Item")
        subject_name = row.fetch("subject_name") { row["item"] || row["name"] }
        next unless subject_type == "Item"
        item = Item.find_by(name: subject_name)
        if item.nil?
          raise "Unknown dismantle subject Item: '#{subject_name}'" unless dry_run
          next
        end
        rule = DismantleRule.find_or_initialize_by(subject_type: "Item", subject_id: item.id)
        rule.notes = row["notes"] if row["notes"]
        save!(rule, dry_run)

        keep_keys = []
        Array(row["yields"]).each do |y|
          type = y.fetch("type")
          name = y.fetch("name")
          qty  = y.fetch("quantity", 1)
          rate = y.fetch("salvage_rate", 1.0)
          quality = y["quality"]
          target = (type == "Resource" ? Resource.find_by(name: name) : Item.find_by(name: name))
          if target.nil?
            raise "Unknown dismantle yield #{type}: '#{name}' for subject '#{subject_name}'" unless dry_run
            next
          end
          dy = DismantleYield.find_or_initialize_by(dismantle_rule_id: rule.id, component_type: type, component_id: target.id)
          dy.quantity = qty
          dy.salvage_rate = rate
          dy.quality = quality
          save!(dy, dry_run)
          keep_keys << [ type, target.id ]
        end

        if prune && !dry_run
          DismantleYield.where(dismantle_rule_id: rule.id).where.not(
            component_type: keep_keys.map(&:first), component_id: keep_keys.map(&:last)
          ).delete_all
        end
      end
      log.call("Seeded dismantle rules: #{dismantles.size}")

      summary = {
        actions: Action.count,
        resources: Resource.count,
        skills: Skill.count,
        items: Item.count,
        buildings: Building.count,
        recipes: Recipe.count,
        flags: Flag.count,
        dismantle_rules: defined?(DismantleRule) ? DismantleRule.count : 0
      }
      log.call("Summary: #{summary}")
      summary
    end

    def model_for(type)
      case type
      when "Resource" then Resource
      when "Item"     then Item
      when "Action"   then Action
      when "Skill"    then Skill
      when "Building" then Building
      when "Flag"     then Flag
      else raise "Unknown type: #{type}"
      end
    end

    def upsert(model, by:, attrs:, dry_run: false)
      keys = Array(by)
      find = attrs.slice(*keys).presence || keys.to_h { |k| [ k, attrs[k.to_s] ] }
      rec = model.find_or_initialize_by(find)
      rec.assign_attributes(attrs.except(*keys).presence || attrs.reject { |k, _| keys.map(&:to_s).include?(k.to_s) })
      save!(rec, dry_run)
      rec
    end

    def find_or_init(model, by: {})
      model.find_or_initialize_by(by)
    end

    def save!(record, dry_run)
      return record unless record.changed?
      return record if dry_run
      record.save!
      record
    end
    end
  end
