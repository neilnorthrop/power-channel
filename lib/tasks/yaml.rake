# frozen_string_literal: true

require "yaml"
require "fileutils"
require "pathname"

namespace :yaml do
  desc "Collapse legacy resource YAML files into aggregate bundle"
  task collapse: :environment do
    data_dir = Seeds::Loader.data_dir
    schema = YamlSchema::Definition.new
    resources = YamlExporter.resources
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
    aggregate = { "core" => {}, "packs" => {} }
    core_files = []
    pack_files = []

    resources.each do |resource|
      file = data_dir.join("#{resource}.yml")
      next unless File.exist?(file)

      rows = Array(YAML.safe_load(File.read(file), aliases: true))
      normalized = rows.map { |row| YamlTasks.stringify_yaml_row(row) }
      normalized.each { |row| schema.validate!(resource, row, context: :core) }
      aggregate["core"][resource] = normalized unless normalized.empty?
      core_files << file
    end

    packs_root = data_dir.join("packs")
    if Dir.exist?(packs_root)
      Dir.children(packs_root).sort.each do |entry|
        next if entry.start_with?(".")
        entry_path = packs_root.join(entry)

        if entry_path.directory?
          pack_rows = {}
          resources.each do |resource|
            file = entry_path.join("#{resource}.yml")
            next unless File.exist?(file)
            rows = Array(YAML.safe_load(File.read(file), aliases: true))
            normalized = rows.map { |row| YamlTasks.stringify_yaml_row(row) }
            normalized.each { |row| schema.validate!(resource, row, context: :pack) }
            pack_rows[resource] = normalized unless normalized.empty?
            pack_files << file
          end
          aggregate["packs"][entry] = pack_rows if pack_rows.any?
        elsif entry_path.file? && entry_path.extname == ".yml"
          pack_name = entry_path.basename(".yml").to_s
          content = YAML.safe_load(File.read(entry_path), aliases: true) || {}
          pack_rows = {}
          content.each do |resource, rows|
            next unless resources.include?(resource.to_s)
            arr = Array(rows).map { |row| YamlTasks.stringify_yaml_row(row) }
            arr.each { |row| schema.validate!(resource, row, context: :pack) }
            pack_rows[resource.to_s] = arr unless arr.empty?
          end
          aggregate["packs"][pack_name] = pack_rows if pack_rows.any?
          pack_files << entry_path
        end
      end
    end

    if aggregate["core"].empty? && aggregate["packs"].empty?
      YamlTasks.log "No legacy YAML content found to collapse."
      next
    end

    target = data_dir.join("aether.yml")
    YamlTasks.log "Building aggregate bundle at #{target}"

    if dry_run
      YamlTasks.log "[DRY RUN] Would write #{target}"
      YamlTasks.log "[DRY RUN] Would backup core files: #{core_files.join(', ')}" if core_files.any?
      YamlTasks.log "[DRY RUN] Would backup pack files: #{pack_files.join(', ')}" if pack_files.any?
      next
    end

    YamlTasks.backup_existing(target)
    aggregate_yaml = aggregate.to_yaml
    File.write(target, aggregate_yaml)

    (core_files + pack_files).each do |file|
      YamlTasks.backup_file(Pathname.new(file))
    end
  end
end

module YamlTasks
  module_function

  def stringify_yaml_row(row)
    return {} unless row.is_a?(Hash)
    row.each_with_object({}) do |(key, value), acc|
      acc[key.to_s] = value
    end
  end

  def backup_existing(target)
    return unless target.exist?
    backup_file(target)
  end

  def backup_file(path)
    backup = Pathname.new("#{path}.bak")
    FileUtils.mv(path, backup)
  end

  def log(message)
    return if Rails.env.test? || ENV["YAML_TASK_SILENT"].present?
    puts message
  end
end
