# frozen_string_literal: true

namespace :seeds do
  desc 'Load YAML content and validate references without writing'
  task :dry_run => :environment do
    require Rails.root.join('lib', 'seeds', 'loader').to_s
    Seeds::Loader.apply!(dry_run: true, prune: ENV['PRUNE'].present?)
  end

  desc 'Lint YAML shapes and reference integrity (basic)'
  task :lint => :environment do
    require 'yaml'
    data_dir = Rails.root.join('db', 'data')
    files = %w[actions.yml resources.yml skills.yml items.yml buildings.yml recipes.yml flags.yml]
    missing = files.reject { |f| File.exist?(data_dir.join(f)) }
    abort("Missing YAML files: #{missing.join(', ')}") if missing.any?

    # Basic shape checks
    actions = YAML.safe_load(File.read(data_dir.join('actions.yml')))
    abort('actions.yml must be an array') unless actions.is_a?(Array)

    %w[resources.yml skills.yml items.yml buildings.yml].each do |f|
      arr = YAML.safe_load(File.read(data_dir.join(f)))
      abort("#{f} must be an array") unless arr.is_a?(Array)
    end

    recipes = YAML.safe_load(File.read(data_dir.join('recipes.yml')))
    abort('recipes.yml must be an array') unless recipes.is_a?(Array)
    recipes.each do |r|
      abort('recipe requires item') unless r['item'].present?
      comps = r['components'] || []
      abort('recipe.components must be an array') unless comps.is_a?(Array)
      comps.each do |c|
        abort('component requires type/name/quantity') unless c['type'] && c['name'] && c['quantity']
      end
    end

    flags = YAML.safe_load(File.read(data_dir.join('flags.yml')))
    abort('flags.yml must be an array') unless flags.is_a?(Array)
    puts 'Seeds lint OK'
  end
end
