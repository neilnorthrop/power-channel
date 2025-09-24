# frozen_string_literal: true

require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
  end

  test "show returns current user when authorized" do
    get api_v1_user_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    attrs = body.dig("data", "attributes") || {}
    %w[email level experience skill_points experimental_crafting].each do |k|
      assert_includes attrs.keys, k
    end
  end

  test "show without auth returns 401" do
    get api_v1_user_url, as: :json
    assert_response :unauthorized
  end
end
