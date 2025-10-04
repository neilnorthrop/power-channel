# frozen_string_literal: true

require "test_helper"

class Owner::DismantlesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "dismantle-owner@example.com", password: "password", role: :owner)
    sign_in @owner, scope: :user
  end

  test "edit renders owner validate dismantle helper" do
    item = Item.create!(name: "Old Axe")
    rule = DismantleRule.create!(subject: item)

    get edit_owner_dismantle_path(rule)

    assert_response :success
    assert_includes @response.body, owner_validate_dismantle_path(rule)
  end
end
