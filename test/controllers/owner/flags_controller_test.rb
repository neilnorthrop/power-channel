# frozen_string_literal: true

require "test_helper"

class Owner::FlagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "flags-owner@example.com", password: "password", role: :owner)
    sign_in @owner
  end

  test "new renders owner validation helper" do
    get new_owner_flag_path

    assert_response :success
    assert_includes @response.body, owner_validate_flags_path
  end
end
