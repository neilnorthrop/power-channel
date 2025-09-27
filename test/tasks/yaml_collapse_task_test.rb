# frozen_string_literal: true

require "test_helper"
require "rake"

class YamlCollapseTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("yaml:collapse")
    Rake::Task["yaml:collapse"].reenable
  end

  test "dry run leaves legacy files untouched" do
    with_temp_yaml_dir do |dir|
      File.write(dir.join("actions.yml"), <<~YAML)
        - name: Core Chop
      YAML

      FileUtils.mkdir_p(dir.join("packs", "forest"))
      File.write(dir.join("packs", "forest", "actions.yml"), <<~YAML)
        - name: Pack Chop
      YAML

      Seeds::Loader.stubs(:data_dir).returns(dir)
      begin
        ENV["DRY_RUN"] = "1"
        Rake::Task["yaml:collapse"].invoke
      ensure
        ENV.delete("DRY_RUN")
        Seeds::Loader.unstub(:data_dir)
        if Seeds::Loader.instance_variable_defined?(:@aggregate_reader)
          Seeds::Loader.remove_instance_variable(:@aggregate_reader)
        end
      end

      refute dir.join("aether.yml").exist?
      assert dir.join("actions.yml").exist?
      assert dir.join("packs", "forest", "actions.yml").exist?
    end
  end

  test "collapse writes aggregate bundle and backups" do
    with_temp_yaml_dir do |dir|
      File.write(dir.join("actions.yml"), <<~YAML)
        - name: Core Chop
      YAML

      FileUtils.mkdir_p(dir.join("packs", "forest"))
      File.write(dir.join("packs", "forest", "actions.yml"), <<~YAML)
        - name: Pack Chop
      YAML

      Seeds::Loader.stubs(:data_dir).returns(dir)
      begin
        Rake::Task["yaml:collapse"].invoke
      ensure
        Seeds::Loader.unstub(:data_dir)
        if Seeds::Loader.instance_variable_defined?(:@aggregate_reader)
          Seeds::Loader.remove_instance_variable(:@aggregate_reader)
        end
      end

      aggregate_path = dir.join("aether.yml")
      assert aggregate_path.exist?

      payload = YAML.safe_load(File.read(aggregate_path))
      core_names = payload.fetch("core").fetch("actions").map { |row| row["name"] }
      pack_names = payload.fetch("packs").fetch("forest").fetch("actions").map { |row| row["name"] }
      assert_includes core_names, "Core Chop"
      assert_includes pack_names, "Pack Chop"

      assert dir.join("actions.yml.bak").exist?
      assert dir.join("packs", "forest", "actions.yml.bak").exist?
      refute dir.join("actions.yml").exist?
      refute dir.join("packs", "forest", "actions.yml").exist?
    end
  end
end
