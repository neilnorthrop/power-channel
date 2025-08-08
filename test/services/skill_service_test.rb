# frozen_string_literal: true

require "test_helper"

class SkillServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @skill = skills(:one)
    @user.skills.destroy_all
  end

  test "should unlock skill" do
    @user.update(skill_points: 1)
    service = SkillService.new(@user)
    result = service.unlock_skill(@skill.id)

    assert result[:success]
    assert @user.skills.include?(@skill)
    assert_equal 0, @user.skill_points
  end

  test "should not unlock skill if already unlocked" do
    @user.skills << @skill
    @user.update(skill_points: 1)
    service = SkillService.new(@user)
    result = service.unlock_skill(@skill.id)

    assert_not result[:success]
    assert_equal "Skill already unlocked.", result[:error]
  end

  test "should not unlock skill if not enough skill points" do
    @user.update(skill_points: 0)
    service = SkillService.new(@user)
    result = service.unlock_skill(@skill.id)

    assert_not result[:success]
    assert_equal "Not enough skill points.", result[:error]
  end
end
