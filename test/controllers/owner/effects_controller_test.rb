# frozen_string_literal: true

require "test_helper"

class Owner::EffectsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "effects-owner@example.com", password: "password", role: :owner)
    sign_in @owner, scope: :user
  end

  test "new renders owner validation helper" do
    get new_owner_effect_path

    assert_response :success
    assert_includes @response.body, owner_validate_effects_path
  end

  test "edit renders owner validation helper" do
    item = Item.create!(name: "Elixir", description: "Restores energy")
    effect = Effect.create!(
      name: "Boost",
      description: "Increase strength",
      target_attribute: "strength",
      modifier_type: "add",
      modifier_value: 1.5,
      duration: 60,
      effectable: item
    )

    get edit_owner_effect_path(effect)

    assert_response :success
    assert_includes @response.body, owner_validate_effect_path(effect)
  end
end
