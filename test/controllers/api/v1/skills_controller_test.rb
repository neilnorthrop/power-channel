# frozen_string_literal: true

require "test_helper"

class Api::V1::SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = JsonWebToken.encode(user_id: @user.id)
    @skill = skills(:one)
    @user.update(skill_points: 1)
  end

  test "should get index" do
    get api_v1_skills_url, headers: { Authorization: "Bearer #{@token}" }, as: :json
    assert_response :success
  end

  test "should create skill" do
    assert_difference("UserSkill.count") do
      post api_v1_skills_url, params: { skill_id: @skill.id }, headers: { Authorization: "Bearer #{@token}" }, as: :json
    end

    assert_response :success
  end
end
