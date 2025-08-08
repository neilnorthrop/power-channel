# frozen_string_literal: true

require 'test_helper'

class ActionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @action = actions(:one)
    @resource = resources(:one)
    @resource.update(action: @action)
  end

  test 'should perform action and gain experience' do
    service = ActionService.new(@user)
    initial_experience = @user.experience
    initial_resource_amount = @user.user_resources.find_by(resource: @resource)&.amount || 0

    result = service.perform_action(@action.id)

    assert result[:success]
    assert_equal initial_experience + 10, @user.reload.experience
    assert_equal initial_resource_amount + @resource.base_amount, @user.user_resources.find_by(resource: @resource).amount
  end

  test 'should not perform action if on cooldown' do
    service = ActionService.new(@user)
    service.perform_action(@action.id)
    result = service.perform_action(@action.id)

    assert_not result[:success]
    assert_equal 'Action is on cooldown.', result[:error]
  end
end
