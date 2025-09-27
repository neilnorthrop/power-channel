# frozen_string_literal: true

require "yaml"
require "yaml_schema/definition"

module Seeds
  class AggregateReader
    def initialize(data_dir:, schema: YamlSchema::Definition.new)
      @data_dir = data_dir
      @schema = schema
    end

    def available?
      aggregate_path.exist?
    end

    def resource_rows(resource, pack_names)
      resource_rows_with_source(resource, pack_names).map(&:first)
    end

    def resource_rows_with_source(resource, pack_names)
      rows = Array(core_bundle.fetch(resource.to_s, [])).map do |row|
        [normalize_row(resource, row), "core"]
      end
      pack_names.each do |pack|
        pack_entries = Array(pack_bundle(pack).fetch(resource.to_s, [])).map do |row|
          [normalize_row(resource, row, context: :pack), pack]
        end
        rows.concat(pack_entries)
      end
      rows
    end

    private

    attr_reader :data_dir, :schema

    def aggregate_data
      @aggregate_data ||= begin
        return {} unless available?
        YAML.safe_load(File.read(aggregate_path), aliases: true) || {}
      end
    end

    def core_bundle
      aggregate_data.fetch("core", {})
    end

    def pack_bundle(pack)
      aggregate_data.fetch("packs", {}).fetch(pack, {})
    end

    def normalize_row(resource, row, context: :core)
      return {} if row.nil?
      normalized = stringify_keys(row)
      schema.validate!(resource, normalized, context:)
      normalized
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end

    def aggregate_path
      data_dir.join("aether.yml")
    end
  end
end
