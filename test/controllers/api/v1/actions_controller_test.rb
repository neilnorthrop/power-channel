# frozen_string_literal: true

require "test_helper"

class Api::V1::ActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @action = actions(:gather_taxes)
  end

  test "should get index" do
    get api_v1_actions_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "index sorts descending by order then name" do
    # Ensure the user has multiple actions to sort
    wood = actions(:gather_wood)
    @user.user_actions.find_or_create_by!(action: wood)

    get api_v1_actions_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    data = body["data"] || []
    included = (body["included"] || []).select { |inc| inc["type"] == "action" }
    name_for_action_id = included.to_h { |inc| [ inc["id"], inc.dig("attributes", "name") ] }
    ordered_names = data.map { |row| name_for_action_id[row.dig("relationships", "action", "data", "id")] }
    # With descending fallback, 'Wood' should appear before 'Taxes'
    assert_equal ordered_names.sort.reverse, ordered_names, "Expected descending sort by order then name"
  end

  test "should create action" do
    @user.user_actions.destroy_all
    assert_difference("UserAction.count") do
      post api_v1_actions_url, params: { action_id: @action.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end

  test "create instantiates action service once per request with a single action_id" do
    performed_ids = []
    service = Object.new
    service.define_singleton_method(:perform_action) do |action_id|
      performed_ids << action_id
      { success: true, message: "ok" }
    end

    ActionService.expects(:new).once.with(@user).returns(service)

    post api_v1_actions_url, params: { action_id: @action.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json

    assert_response :success
    assert_equal [ @action.id ], performed_ids
  end

  test "should update action" do
    user_action = @user.user_actions.create(action: @action)
    patch api_v1_action_url(user_action), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end
end
