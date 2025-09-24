# frozen_string_literal: true

require "test_helper"

class Api::V1::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    # Seed a few events
    Event.create!(user: @user, level: "info", message: "hello")
    Event.create!(user: @user, level: "warning", message: "warn")
  end

  test "filters by level" do
    get api_v1_events_url, params: { level: "warning" }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    levels = (body["data"] || []).map { |e| e.dig("attributes", "level") }.uniq
    assert_equal [ "warning" ], levels
  end

  test "handles invalid timestamps" do
    get api_v1_events_url, params: { since: "not-a-time", before: "also-bad" }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "enforces limit bounds" do
    get api_v1_events_url, params: { limit: 9999 }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    assert_operator (body["data"] || []).length, :<=, 200
  end
end
