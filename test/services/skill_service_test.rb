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

  test "should apply skill effects correctly" do
    service = SkillService.new(@user)
    initial_cooldown = 100
    initial_amount = 10

    # Test tax gain skill
    @user.skills << skills(:one) # Tax Lawyer
    cooldown, amount = service.apply_skills_to_action(actions(:gather_taxes), initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_equal 11, amount
    @user.skills.destroy_all

    # Test wood cooldown skill
    @user.skills << skills(:two) # Lumberjack
    cooldown, amount = service.apply_skills_to_action(actions(:gather_wood), initial_cooldown, initial_amount)
    assert_equal 90, cooldown
    assert_equal initial_amount, amount
    @user.skills.destroy_all

    # Test wood gain skill
    @user.skills << skills(:three) # Woodcutter
    cooldown, amount = service.apply_skills_to_action(actions(:gather_wood), initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_equal 11, amount
    @user.skills.destroy_all

    # Test tax cooldown skill
    @user.skills << skills(:four) # Tax Collector
    cooldown, amount = service.apply_skills_to_action(actions(:gather_taxes), initial_cooldown, initial_amount)
    assert_equal 90, cooldown
    assert_equal initial_amount, amount
    @user.skills.destroy_all

    # Test stone gain skill
    @user.skills << skills(:five) # Stone Gatherer
    cooldown, amount = service.apply_skills_to_action(actions(:gather_stone), initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_equal 11, amount
    @user.skills.destroy_all

    # Test stone cooldown skill
    @user.skills << skills(:six) # Stone Mason
    cooldown, amount = service.apply_skills_to_action(actions(:gather_stone), initial_cooldown, initial_amount)
    assert_equal 90, cooldown
    assert_equal initial_amount, amount
    @user.skills.destroy_all
  end
end
