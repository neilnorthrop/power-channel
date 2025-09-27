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

  test "show returns 403 for suspended user" do
    @user.update!(suspended: true, suspended_until: 1.hour.from_now)
    get api_v1_user_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :forbidden
    body = JSON.parse(@response.body)
    assert_equal "account_suspended", body["error"]
  end

  test "show returns 401 for expired token" do
    expired = JsonWebToken.encode({ user_id: @user.id }, 1.hour.ago)
    get api_v1_user_url, headers: { Authorization: "Bearer #{expired}" }, as: :json
    assert_response :unauthorized
    body = JSON.parse(@response.body)
    assert_equal "token_expired", body["error"]
  end
end
