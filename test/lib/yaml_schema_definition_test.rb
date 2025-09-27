# frozen_string_literal: true

require "test_helper"
require "yaml_schema/definition"

class YamlSchemaDefinitionTest < ActiveSupport::TestCase
  def setup
    @definition = YamlSchema::Definition.new
  end

  test "core resources include actions" do
    assert_includes @definition.core_resources, "actions"
  end

  test "pack resources mirror core set" do
    assert_equal @definition.core_resources.sort, @definition.pack_resources.sort
  end

  test "validate! accepts well formed row" do
    assert @definition.validate!("actions", { "name" => "Chop" })
  end

  test "validate! rejects missing required keys" do
    error = assert_raises(YamlSchema::ValidationError) do
      @definition.validate!("actions", {})
    end
    assert_match "Missing required keys", error.message
  end

  test "validate! rejects unsupported keys" do
    error = assert_raises(YamlSchema::ValidationError) do
      @definition.validate!("actions", { "name" => "Chop", "invalid" => true })
    end
    assert_match "Unsupported keys", error.message
  end

  test "pack validation uses same schema" do
    assert @definition.validate!("actions", { "name" => "Pack Chop" }, context: :pack)
  end
end
