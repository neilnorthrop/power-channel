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

  test "orders ascending by created_at and supports before boundary" do
    # Add two more events with distinct timestamps
    e1 = Event.create!(user: @user, level: "info", message: "older", created_at: 2.hours.ago)
    e2 = Event.create!(user: @user, level: "info", message: "newer", created_at: 1.hour.ago)
    get api_v1_events_url, params: { since: 3.hours.ago.iso8601, before: Time.current.iso8601, limit: 100 }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    msgs = (body["data"] || []).map { |e| e.dig("attributes", "message") }
    # Ascending: older should appear before newer when both present
    assert_operator msgs.index("older"), :<, msgs.index("newer")
    # Boundary filter: request with before set to e2's created_at should exclude newer
    get api_v1_events_url, params: { since: 3.hours.ago.iso8601, before: e2.created_at.iso8601, limit: 100 }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body2 = JSON.parse(@response.body)
    msgs2 = (body2["data"] || []).map { |e| e.dig("attributes", "message") }
    assert_includes msgs2, "older"
    assert_not_includes msgs2, "newer"
  end
end
