# frozen_string_literal: true

require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Ensure the test env has a predictable secret
    Rails.application.config.stubs(:jwt_secret).returns("test-secret-key")
  end

  test "authorized request with valid token succeeds" do
    token = JsonWebToken.encode(user_id: @user.id)
    get api_v1_resources_url, headers: { Authorization: "Bearer #{token}" }
    assert_response :success
  end

  test "request with expired token returns 401" do
    token = JsonWebToken.encode({ user_id: @user.id }, 1.second.ago)
    get api_v1_resources_url, headers: { Authorization: "Bearer #{token}" }
    assert_response :unauthorized
    body = JSON.parse(response.body) rescue {}
    assert_equal "token_expired", body["error"]
  end

  test "request without token returns 401" do
    get api_v1_resources_url
    assert_response :unauthorized
  end
end

