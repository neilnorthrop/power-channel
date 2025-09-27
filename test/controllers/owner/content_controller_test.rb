# frozen_string_literal: true

require "test_helper"

class Owner::ContentControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "owner-content@example.com", password: "password", role: :owner)
    sign_in @owner, scope: :user
  end

  test "actions index can sort by order column" do
    Action.create!(name: "Gather Wood", description: "Collect", cooldown: 1, order: 2)
    Action.create!(name: "Mine Ore", description: "Dig", cooldown: 1, order: 1)

    get owner_content_index_path, params: { resource: "actions" }

    assert_response :success
    body = @response.body
    assert_includes body, "Gather Wood"
    assert_includes body, "Mine Ore"
  end

  test "export validate returns preview payload" do
    Action.create!(name: "Preview Chop", order: 5)

    post export_validate_owner_content_index_path, params: { resource: "actions" }, as: :json

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "actions.yml", body["file"]
    assert_equal "Preview Chop", body["rows"].first["name"]
  end

  test "export without override uses defaults" do
    YamlExporter.expects(:export!).with("actions").returns(Pathname.new("#{Rails.root}/db/data/aether.yml"))

    post export_owner_content_index_path, params: { resource: "actions" }

    assert_redirected_to owner_content_index_path(resource: "actions")
  end

end
