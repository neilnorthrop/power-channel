# frozen_string_literal: true

namespace :seeds do
  desc "Load YAML content and validate references without writing"
  task dry_run: :environment do
    require Rails.root.join("lib", "seeds", "loader").to_s
    Seeds::Loader.apply!(dry_run: true, prune: ENV["PRUNE"].present?)
  end

  desc "Plan seeding: show effective packs, sources, and counts without writing"
  task plan: :environment do
    # Future idea: enrich output with per-file row counts and overlay breakdown
    # (core vs each pack), e.g., actions.yml=10, woodworking/actions.yml=4, etc.
    # Also show which rows would be updated vs created.
    require Rails.root.join("lib", "seeds", "loader").to_s
    data_dir = Rails.root.join("db", "data")
    files = %w[actions.yml resources.yml skills.yml items.yml buildings.yml recipes.yml flags.yml dismantle.yml]

    packs = Seeds::Loader.selected_pack_names
    puts "Packs selected: #{packs.any? ? packs.join(', ') : '(none)'}"

    core_present = files.select { |f| File.exist?(data_dir.join(f)) }
    puts "Core files present: #{core_present.join(', ')}"

    packs.each do |pack|
      dir = data_dir.join("packs", pack)
      present = files.select { |f| File.exist?(dir.join(f)) }
      puts "Pack '#{pack}' files: #{present.any? ? present.join(', ') : '(none)'}"
    end

    summary = Seeds::Loader.apply!(dry_run: true, prune: ENV["PRUNE"].present?)
    # Pretty print summary
    order = %i[actions resources skills items buildings recipes flags dismantle_rules]
    line = order.map { |k| "#{k}=#{summary[k] || 0}" }.join(", ")
    puts "Planned counts: #{line}"
  end

  desc "Lint YAML shapes and reference integrity (basic)"
  task lint: :environment do
    require "yaml"
    data_dir = Rails.root.join("db", "data")
    files = %w[actions.yml resources.yml skills.yml items.yml buildings.yml recipes.yml flags.yml dismantle.yml]
    # It's valid to have zero core files when using packs. Only abort if a file
    # is missing in both core and all selected packs.

    # Resolve packs (PACKS/EXCLUDE) similarly to loader to validate pack files
    packs_env = ENV["PACKS"]&.strip
    exclude_env = ENV["EXCLUDE"]&.strip
    selected_packs = []
    if packs_env.present?
      if packs_env.downcase == "all"
        packs_root = Rails.root.join("db", "data", "packs")
        selected_packs = Dir.exist?(packs_root) ? Dir.children(packs_root).select { |c| File.directory?(packs_root.join(c)) } : []
      else
        selected_packs = packs_env.split(",").map(&:strip).reject(&:empty?)
      end
    end
    if exclude_env.present?
      if exclude_env.downcase == "all"
        selected_packs = []
      else
        excludes = exclude_env.split(",").map { |x| x.strip.downcase }
        selected_packs = selected_packs.reject { |p| excludes.include?(p.downcase) }
      end
    end

    # For each required file, ensure it exists in core or any selected pack
    files.each do |fname|
      core_exists = File.exist?(data_dir.join(fname))
      pack_exists = selected_packs.any? { |p| File.exist?(data_dir.join("packs", p, fname)) }
      abort("Missing YAML for #{fname} in core and selected packs") unless core_exists || pack_exists
    end

    # Basic shape checks: only validate files that exist
    if File.exist?(data_dir.join("actions.yml"))
      actions = YAML.safe_load(File.read(data_dir.join("actions.yml")))
      abort("actions.yml must be an array") unless actions.is_a?(Array)
    end

    %w[resources.yml skills.yml items.yml buildings.yml].each do |f|
      path = data_dir.join(f)
      next unless File.exist?(path)
      arr = YAML.safe_load(File.read(path))
      abort("#{f} must be an array") unless arr.is_a?(Array)
    end

    if File.exist?(data_dir.join("recipes.yml"))
      recipes = YAML.safe_load(File.read(data_dir.join("recipes.yml")))
      abort("recipes.yml must be an array") unless recipes.is_a?(Array)
      recipes.each do |r|
        abort("recipe requires item") unless r["item"].present?
        comps = r["components"] || []
        abort("recipe.components must be an array") unless comps.is_a?(Array)
        comps.each do |c|
          abort("component requires type/name/quantity") unless c["type"] && c["name"] && c["quantity"]
        end
      end
    end

    if File.exist?(data_dir.join("flags.yml"))
      flags = YAML.safe_load(File.read(data_dir.join("flags.yml")))
      abort("flags.yml must be an array") unless flags.is_a?(Array)
    end
    # PACKS/EXCLUDE support: resolve pack list and validate files if present
    packs_env = ENV["PACKS"]&.strip
    exclude_env = ENV["EXCLUDE"]&.strip
    selected_packs.each do |pack|
      dir = Rails.root.join("db", "data", "packs", pack)
      abort("Missing pack folder: #{dir}") unless Dir.exist?(dir)
      %w[actions.yml resources.yml skills.yml items.yml buildings.yml recipes.yml flags.yml].each do |fname|
        path = dir.join(fname)
        next unless File.exist?(path)
        arr = YAML.safe_load(File.read(path))
        abort("#{path} must be an array") unless arr.is_a?(Array)
        if fname == "resources.yml"
          arr.each do |r|
            if r["min_amount"] && r["max_amount"]
              abort("#{path}: min_amount must be <= max_amount for #{r['name']}") if r["min_amount"].to_i > r["max_amount"].to_i
            end
          end
        end
      end
    end

    puts "Seeds lint OK"
  end
end
