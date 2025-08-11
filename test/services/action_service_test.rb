# frozen_string_literal: true

require "test_helper"

class ActionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @action = actions(:gather_taxes)
    @resource = resources(:gold)
    @user.user_skills.destroy_all
  end

  test "should perform action and gain experience" do
    mock_skill_service = mock("skill_service")
    mock_skill_service.stubs(:apply_skills_to_action).returns([ @action.cooldown, @resource.base_amount ])
    SkillService.stubs(:new).returns(mock_skill_service)

    service = ActionService.new(@user)
    initial_experience = @user.experience
    initial_resource_amount = @user.user_resources.find_by(resource: @resource)&.amount || 0

    result = service.perform_action(@action.id)

    assert result[:success]
    assert_equal initial_experience + 10, @user.reload.experience
    assert_equal initial_resource_amount + @resource.base_amount, @user.user_resources.find_by(resource: @resource).amount
  end

  test "should not perform action if on cooldown" do
    service = ActionService.new(@user)
    service.perform_action(@action.id)
    result = service.perform_action(@action.id)

    assert_not result[:success]
    assert_equal "Action is on cooldown.", result[:error]
  end

  test "should not perform action if action does not exist" do
    service = ActionService.new(@user)
    result = service.perform_action(999)

    assert_not result[:success]
    assert_equal "Action not found.", result[:error]
  end
end
