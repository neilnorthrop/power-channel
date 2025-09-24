# frozen_string_literal: true

require "test_helper"

class Api::V1::ResourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
  end

  test "index returns resources for current user" do
    get api_v1_resources_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    data = body["data"] || []
    assert data.is_a?(Array)
  end

  test "index without auth returns 401" do
    get api_v1_resources_url, as: :json
    assert_response :unauthorized
  end
end
