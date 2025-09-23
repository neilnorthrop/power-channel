# frozen_string_literal: true

require "test_helper"

class ActionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @action = actions(:gather_taxes)
    @resource = resources(:gold)
    @user.user_skills.destroy_all
    ActiveEffect.delete_all
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

  test "probabilistic fractional adds one when rand below frac" do
    action = actions(:gather_wood)
    res = resources(:wood)
    res.update!(min_amount: 3, max_amount: 3) # deterministic base quantity

    # +20% luck total → +10% quantity; exact = 3 * 1.1 = 3.3 ⇒ frac = 0.3
    ActiveEffect.create!(user: @user, effect: effects(:luck), expires_at: 1.hour.from_now)

    # Stub skill service to return the base unchanged
    mock_skill_service = mock("skill_service")
    mock_skill_service.stubs(:apply_skills_to_action).returns([ action.cooldown, 3 ])
    SkillService.stubs(:new).returns(mock_skill_service)

    ur = @user.user_resources.find_or_create_by!(resource: res) { |r| r.amount = 0 }
    before = ur.amount

    # rand calls: first for success (<1), second for fractional (<0.3 triggers +1)
    Kernel.stubs(:rand).returns(0.0, 0.1)
    result = ActionService.new(@user).perform_action(action.id)
    assert result[:success], result[:error]
    assert_equal before + 4, ur.reload.amount
  end

  test "probabilistic fractional does not add when rand above frac" do
    action = actions(:gather_wood)
    res = resources(:wood)
    res.update!(min_amount: 3, max_amount: 3)

    ActiveEffect.create!(user: @user, effect: effects(:luck), expires_at: 1.hour.from_now)

    mock_skill_service = mock("skill_service")
    mock_skill_service.stubs(:apply_skills_to_action).returns([ action.cooldown, 3 ])
    SkillService.stubs(:new).returns(mock_skill_service)

    ur = @user.user_resources.find_or_create_by!(resource: res) { |r| r.amount = 0 }
    before = ur.amount

    # rand calls: success 0.0, fractional 0.9 (> 0.3) → no +1
    Kernel.stubs(:rand).returns(0.0, 0.9)
    result = ActionService.new(@user).perform_action(action.id)
    assert result[:success], result[:error]
    assert_equal before + 3, ur.reload.amount
  end

  test "should not perform action if action does not exist" do
    service = ActionService.new(@user)
    result = service.perform_action(999)

    assert_not result[:success]
    assert_equal "Action not found.", result[:error]
  end
end
