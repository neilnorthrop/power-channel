# frozen_string_literal: true

require "test_helper"

class SkillServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    # Ensure a clean slate of skills for these tests
    @user.user_skills.destroy_all
    @user.update!(skill_points: 10)
    @action_taxes = actions(:gather_taxes)
    @resource_taxes = resources(:gold)
    @action_wood = actions(:gather_wood)
    @resource_wood = resources(:wood)
    @action_stone = actions(:gather_stone)
    @resource_stone = resources(:stone)

    @skill_tax_gain = skills(:one)
    @skill_wood_cooldown = skills(:two)
    @skill_wood_gain = skills(:three)
    @skill_tax_cooldown = skills(:four)
    @skill_stone_gain = skills(:five)
    @skill_stone_cooldown = skills(:six)
    # Dedicated critical skill for this test suite
    @skill_critical = Skill.create!(name: "Critical (test)", description: "Double resource gain", cost: 1, effect: "critical_all_gain", multiplier: 2.0)
  end

  test "should unlock skill" do
    @user.update(skill_points: 10)
    service = SkillService.new(@user)
    result = service.unlock_skill(@skill_tax_gain.id)

    assert result[:success]
    assert @user.skills.include?(@skill_tax_gain)
    assert_equal 9, @user.skill_points
  end

  test "should not unlock skill if already unlocked" do
    @user.skills << @skill_tax_gain
    service = SkillService.new(@user)
    result = service.unlock_skill(@skill_tax_gain.id)

    assert_not result[:success]
    assert_equal "Skill already unlocked.", result[:error]
  end

  test "should not unlock skill if not enough skill points" do
    @user.update(skill_points: 0)
    service = SkillService.new(@user)
    result = service.unlock_skill(@skill_tax_gain.id)

    assert_not result[:success]
    assert_equal "Not enough skill points.", result[:error]
  end

  test "should apply skill effects correctly" do
    service = SkillService.new(@user)
    initial_cooldown = 100
    initial_amount = 10

    # Test tax gain skill
    @user.skills << @skill_tax_gain
    cooldown, amount = service.apply_skills_to_action(@action_taxes, initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_in_delta 11, amount
    @user.skills.destroy_all

    # Test wood cooldown skill
    @user.skills << @skill_wood_cooldown
    cooldown, amount = service.apply_skills_to_action(@action_wood, initial_cooldown, initial_amount)
    assert_in_delta 90, cooldown
    assert_equal initial_amount, amount
    @user.skills.destroy_all

    # Test wood gain skill
    @user.skills << @skill_wood_gain
    cooldown, amount = service.apply_skills_to_action(@action_wood, initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_in_delta 11, amount
    @user.skills.destroy_all

    # Test tax cooldown skill
    @user.skills << @skill_tax_cooldown
    cooldown, amount = service.apply_skills_to_action(@action_taxes, initial_cooldown, initial_amount)
    assert_in_delta 90, cooldown
    assert_equal initial_amount, amount
    @user.skills.destroy_all

    # Test stone gain skill
    @user.skills << @skill_stone_gain
    cooldown, amount = service.apply_skills_to_action(@action_stone, initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_in_delta 11, amount
    @user.skills.destroy_all

    # Test stone cooldown skill
    @user.skills << @skill_stone_cooldown
    cooldown, amount = service.apply_skills_to_action(@action_stone, initial_cooldown, initial_amount)
    assert_in_delta 90, cooldown
    assert_equal initial_amount, amount
    @user.skills.destroy_all

    # Test applying multiple skills simultaneously
    @user.skills << @skill_wood_cooldown
    @user.skills << @skill_wood_gain
    cooldown, amount = service.apply_skills_to_action(@action_wood, initial_cooldown, initial_amount)
    assert_in_delta 90, cooldown
    assert_in_delta 11, amount
    @user.skills.destroy_all

    # Test critical gain skill
    @user.skills << @skill_critical
    cooldown, amount = service.apply_skills_to_action(@action_taxes, initial_cooldown, initial_amount)
    assert_equal initial_cooldown, cooldown
    assert_in_delta 20, amount
    @user.skills.destroy_all
  end
end
