# frozen_string_literal: true

require "test_helper"

class Api::V1::ActiveEffectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
  end

  test "should get index" do
    get api_v1_active_effects_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end
end
