# frozen_string_literal: true

require "test_helper"
require "yaml"

class YamlExporterTest < ActiveSupport::TestCase
  def with_export_dir
    with_temp_yaml_dir do |dir|
      YamlExporter.stubs(:data_dir).returns(dir)
      yield dir
    ensure
      YamlExporter.unstub(:data_dir)
    end
  end

  def read_bundle(dir)
    YAML.safe_load(File.read(dir.join("aether.yml")))
  end

  test "export actions writes expected rows into aggregate bundle" do
    first = Action.create!(name: "Chop Wood Export", description: "Gather logs", cooldown: 5, order: 10)
    second = Action.create!(name: "Plant Seed Export", order: 20)

    with_export_dir do |dir|
      basename, preview_rows = YamlExporter.preview!("actions")
      assert_equal "actions.yml", basename
      refute dir.join("aether.yml").exist?

      path = YamlExporter.export!("actions")
      assert_equal dir.join("aether.yml"), path
      refute dir.join("actions.yml").exist?

      bundle = read_bundle(dir)
      actions = bundle.fetch("core").fetch("actions")

      export_rows = actions.select { |row| [first.name, second.name].include?(row["name"]) }
      assert_equal 2, export_rows.size
      first_row = export_rows.find { |row| row["name"] == first.name }
      second_row = export_rows.find { |row| row["name"] == second.name }
      assert_equal first.description, first_row["description"]
      assert_equal first.cooldown, first_row["cooldown"]
      assert_equal first.order, first_row["order"]
      assert_equal second.order, second_row["order"]

      assert_equal actions, preview_rows
    end
  end

  test "export flags expands associations by name" do
    FlagRequirement.delete_all
    Unlockable.delete_all
    Flag.where(slug: "has-iron-coin-export").delete_all

    action = Action.create!(name: "Smelt Ore Export", order: 10)
    item   = Item.create!(name: "Iron Coin Export", description: "Currency")
    flag   = Flag.create!(slug: "has-iron-coin-export", name: "Has Iron Coin Export", description: "Wallet upgrade")
    FlagRequirement.create!(flag: flag, requirement: item, quantity: 2, logic: "OR")
    Unlockable.create!(flag: flag, unlockable: action)

    with_export_dir do |dir|
      YamlExporter.export!("flags")

      flags = read_bundle(dir).fetch("core").fetch("flags")
      target = flags.find { |row| row["slug"] == flag.slug }
      refute_nil target
      requirement = target.fetch("requirements").find { |r| r["name"] == item.name }
      refute_nil requirement
      assert_equal 2, requirement["quantity"]
      assert_equal "OR", requirement["logic"]
      unlockable = target.fetch("unlockables").find { |u| u["name"] == action.name }
      refute_nil unlockable
      assert_equal "Action", unlockable["type"]
    end
  end

  test "export all rewrites core while preserving packs" do
    Action.create!(name: "Bundle Chop All", order: 10)
    Item.create!(name: "Bundle Tool All")

    with_export_dir do |dir|
      # Seed existing bundle with pack entries to ensure we preserve them
      File.write(dir.join("aether.yml"), {
        "core" => {
          "actions" => [ { "name" => "Old" } ]
        },
        "packs" => {
          "forest" => { "actions" => [ { "name" => "Pack Action" } ] }
        }
      }.to_yaml)

      YamlExporter.export_all!

      bundle = read_bundle(dir)
      core_actions = bundle.fetch("core").fetch("actions").map { |row| row["name"] }
      core_items   = bundle.fetch("core").fetch("items").map { |row| row["name"] }
      pack_actions = bundle.fetch("packs").fetch("forest").fetch("actions").map { |row| row["name"] }

      assert_includes core_actions, "Bundle Chop All"
      assert_includes core_items, "Bundle Tool All"
      assert_includes pack_actions, "Pack Action"
      refute_includes core_actions, "Old"
    end
  end

  test "subsequent exports retain previous aggregate entries" do
    Action.create!(name: "Chop Persist", order: 10)

    with_export_dir do |dir|
      YamlExporter.export!("actions")
      Item.create!(name: "Persist Tool")
      YamlExporter.export!("items")

      bundle = read_bundle(dir)
      core = bundle.fetch("core")
      assert_includes core.fetch("actions").map { |row| row["name"] }, "Chop Persist"
      assert_includes core.fetch("items").map { |row| row["name"] }, "Persist Tool"
    end
  end
end
