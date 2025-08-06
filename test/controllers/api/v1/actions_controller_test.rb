# frozen_string_literal: true

require 'test_helper'

class Api::V1::ActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @action = actions(:one)
  end

  test 'should get index' do
    get api_v1_actions_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test 'should create action' do
    @user.user_actions.destroy_all
    assert_difference('UserAction.count') do
      post api_v1_actions_url, params: { action_id: @action.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end

  test 'should update action' do
    user_action = @user.user_actions.create(action: @action)
    patch api_v1_action_url(user_action), headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end
end
