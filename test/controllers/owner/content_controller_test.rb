# frozen_string_literal: true

require "test_helper"

class Owner::ContentControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "owner-content@example.com", password: "password", role: :owner)
    sign_in @owner
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
end
