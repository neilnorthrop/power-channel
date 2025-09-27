# frozen_string_literal: true

require "test_helper"

class Owner::ActionItemDropsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "drops-owner@example.com", password: "password", role: :owner)
    @action = Action.create!(name: "Chop Wood", description: "Chop", cooldown: 1)
    sign_in @owner
  end

  test "index renders validate button with correct helper" do
    get owner_action_item_drops_path(action_id: @action.id)

    assert_response :success
    assert_includes @response.body, owner_validate_action_item_drops_path(@action)
  end
end
