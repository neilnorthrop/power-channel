# frozen_string_literal: true

require "yaml"

module YamlSchema
  class ValidationError < StandardError; end

  class Definition
    CONFIG_PATH = Rails.root.join("config", "yaml_schema.yml")

    def initialize(config = nil)
      @config = config || load_config.freeze
    end

    def core_resources
      section_keys("core")
    end

    def pack_resources
      section_keys("packs")
    end

    def schema_for(resource, context: :core)
      section = case context
                when :core then config.fetch("core")
                when :pack then config.fetch("packs")
                else
                  raise ArgumentError, "Unknown context: #{context}"
                end
      schema = section[resource.to_s]
      raise ValidationError, "Unknown resource '#{resource}' for #{context}" unless schema
      schema
    end

    def validate!(resource, row, context: :core)
      schema = schema_for(resource, context:)
      row_keys = row.keys.map(&:to_s)
      required = Array(schema["required"]).map(&:to_s)
      optional = Array(schema["optional"]).map(&:to_s)

      missing = required - row_keys
      raise ValidationError, "Missing required keys #{missing.join(', ')} for #{resource}" if missing.any?

      allowed = required + optional
      extra = row_keys - allowed
      raise ValidationError, "Unsupported keys #{extra.join(', ')} for #{resource}" if extra.any?

      true
    end

    private

    attr_reader :config

    def section_keys(section)
      config.fetch(section).keys
    end

    def load_config
      YAML.safe_load(File.read(CONFIG_PATH), aliases: true)
    rescue Errno::ENOENT => e
      raise ValidationError, "Schema configuration missing: #{e.message}"
    end
  end
end
