# frozen_string_literal: true

require "test_helper"
require "yaml"

class SeedsLoaderApplyTest < ActiveSupport::TestCase
  def with_loader(dir:, packs: [])
    Seeds::Loader.stubs(:data_dir).returns(dir)
    Seeds::Loader.stubs(:selected_pack_names).returns(packs)
    yield
  ensure
    Seeds::Loader.unstub(:data_dir)
    Seeds::Loader.unstub(:selected_pack_names)
    if Seeds::Loader.instance_variable_defined?(:@aggregate_reader)
      Seeds::Loader.remove_instance_variable(:@aggregate_reader)
    end
  end

  test "load_yaml combines core and selected pack entries" do
    with_temp_yaml_dir do |dir|
      File.write(dir.join("aether.yml"), {
        "core" => {
          "resources" => [ { "name" => "Core Wood" } ]
        },
        "packs" => {
          "forest" => {
            "resources" => [ { "name" => "Pack Berry" } ]
          }
        }
      }.to_yaml)

      with_loader(dir:, packs: ["forest"]) do
        rows = Seeds::Loader.load_yaml("resources.yml")
        assert_equal(
          [
            { "name" => "Core Wood" },
            { "name" => "Pack Berry" }
          ],
          rows
        )
      end
    end
  end

  test "load_yaml prefers aggregate bundle when present" do
    with_temp_yaml_dir do |dir|
      bundle = {
        "core" => {
          "resources" => [ { "name" => "Core Ore" } ]
        },
        "packs" => {
          "forest" => {
            "resources" => [ { "name" => "Pack Herb" } ]
          }
        }
      }
      File.write(dir.join("aether.yml"), bundle.to_yaml)

      with_loader(dir:, packs: ["forest"]) do
        rows = Seeds::Loader.load_yaml("resources.yml")
        assert_equal [
          { "name" => "Core Ore" },
          { "name" => "Pack Herb" }
        ], rows
      end
    end
  end

  test "apply! with dry_run uses selected packs without modifying records" do
    counts_before = {
      actions: Action.count,
      resources: Resource.count,
      skills: Skill.count,
      items: Item.count,
      buildings: Building.count,
      recipes: Recipe.count,
      flags: Flag.count
    }

    with_temp_yaml_dir do |dir|
      File.write(dir.join("aether.yml"), {
        "core" => {
          "actions" => [
            { "name" => "Core Chop", "order" => 10, "cooldown" => 5 }
          ]
        },
        "packs" => {
          "forest" => {
            "actions" => [ { "name" => "Pack Hunt", "order" => 20 } ]
          }
        }
      }.to_yaml)

      with_loader(dir:, packs: ["forest"]) do
        summary = Seeds::Loader.apply!(dry_run: true, prune: false, logger: nil)

        counts_before.each do |key, value|
          assert_equal value, summary[key], "expected #{key} count to remain unchanged"
        end
      end
    end

    counts_before.each do |key, value|
      model = key.to_s.classify.constantize
      assert_equal value, model.count, "expected #{key} table to remain unchanged"
    end
  end

  test "apply! with aggregate bundle honours pack overrides" do
    counts_before = {
      actions: Action.count,
      resources: Resource.count,
      skills: Skill.count,
      items: Item.count,
      buildings: Building.count,
      recipes: Recipe.count,
      flags: Flag.count
    }

    with_temp_yaml_dir do |dir|
      bundle = {
        "core" => {
          "actions" => [ { "name" => "Aggregate Chop", "order" => 10, "cooldown" => 3 } ]
        },
        "packs" => {
          "forest" => {
            "actions" => [ { "name" => "Aggregate Hunt", "order" => 20 } ]
          }
        }
      }
      File.write(dir.join("aether.yml"), bundle.to_yaml)

      with_loader(dir:, packs: ["forest"]) do
        summary = Seeds::Loader.apply!(dry_run: true, prune: false, logger: nil)

        counts_before.each do |key, value|
          assert_equal value, summary[key], "expected #{key} count to remain unchanged"
        end
      end
    end

    counts_before.each do |key, value|
      model = key.to_s.classify.constantize
      assert_equal value, model.count, "expected #{key} table to remain unchanged"
    end
  end
end
