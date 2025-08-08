require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "after_create assigns default resources, actions, and starting attributes" do
    user = User.create!(email: "newuser@example.com", password: "password123")
    initialization_service = UserInitializationService.new(user)
    initialization_service.initialize_defaults

    # Check initial attributes
    assert_equal 1, user.level
    assert_equal 0, user.experience
    assert_equal 0, user.skill_points

    # Check default resources assigned
    assert_equal Resource.count, user.user_resources.count, user.user_resources.inspect
    assert_equal Resource.all.pluck(:base_amount).sort, user.user_resources.map(&:amount).sort

    # Check default actions assigned
    assert_equal Action.count, user.user_actions.count
  end

  test "gain_experience increases experience and does not level up below threshold" do
    @user.experience = 0
    @user.level = 1
    @user.skill_points = 0
    @user.save!

    # Gain experience below the threshold
    @user.gain_experience(50)
    assert_equal 50, @user.experience
    assert_equal 1, @user.level
    assert_equal 0, @user.skill_points # skill points should not increase yet
  end

  test "gain_experience increases experience and levels up when threshold is reached" do
    @user.experience = 50
    @user.level = 1
    @user.skill_points = 0
    @user.save!

    # Gain experience below the threshold
    @user.gain_experience(30)
    assert_equal 80, @user.experience
    assert_equal 1, @user.level
    assert_equal 0, @user.skill_points

    # Gain experience to reach the threshold
    @user.gain_experience(20)
    assert_equal 0, @user.experience
    assert_equal 2, @user.level
    assert_equal 1, @user.skill_points # skill points should increase by 1 on level up
  end

  test "level_up increases level and skill_points and resets experience" do
    @user.level = 1
    @user.experience = 100
    @user.skill_points = 0
    @user.send(:level_up)
    assert_equal 2, @user.level
    assert_equal 0, @user.experience
    assert_equal 1, @user.skill_points
  end

  test "experience_for_next_level returns correct amount" do
    @user.level = 1
    assert_equal 100, @user.send(:experience_for_next_level)
    @user.level = 2
    assert_equal 200, @user.send(:experience_for_next_level)
  end

  test "gain_experience handles multiple level ups" do
    @user.level = 1
    @user.experience = 0
    @user.skill_points = 0
    @user.save!

    # Gain enough experience to level up twice
    @user.gain_experience(300)
    assert_equal 3, @user.level
    assert_equal 0, @user.experience
    assert_equal 2, @user.skill_points
  end
end
