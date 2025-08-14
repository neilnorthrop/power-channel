# frozen_string_literal: true

require "test_helper"

class SkillServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password", skill_points: 10)
    @action_taxes = Action.create!(name: "Taxes", description: "Collect taxes", cooldown: 60)
    @resource_taxes = Resource.create!(name: "Taxes", description: "Taxes", base_amount: 10, action: @action_taxes)
    @action_wood = Action.create!(name: "Wood", description: "Chop wood", cooldown: 30)
    @resource_wood = Resource.create!(name: "Wood", description: "Wood", base_amount: 5, action: @action_wood)
    @action_stone = Action.create!(name: "Stone", description: "Mine stone", cooldown: 45)
    @resource_stone = Resource.create!(name: "Stone", description: "Stone", base_amount: 3, action: @action_stone)

    @skill_tax_gain = Skill.create!(name: "Tax Lawyer", description: "Increase tax gain by 10%", cost: 1, effect: "increase_taxes_gain", multiplier: 1.1)
    @skill_wood_cooldown = Skill.create!(name: "Lumberjack", description: "Decrease wood cooldown by 10%", cost: 1, effect: "decrease_wood_cooldown", multiplier: 0.9)
    @skill_wood_gain = Skill.create!(name: "Woodcutter", description: "Increase wood gain by 10%", cost: 1, effect: "increase_wood_gain", multiplier: 1.1)
    @skill_tax_cooldown = Skill.create!(name: "Tax Collector", description: "Decrease tax cooldown by 10%", cost: 1, effect: "decrease_taxes_cooldown", multiplier: 0.9)
    @skill_stone_gain = Skill.create!(name: "Stone Gatherer", description: "Increase stone gain by 10%", cost: 1, effect: "increase_stone_gain", multiplier: 1.1)
    @skill_stone_cooldown = Skill.create!(name: "Stone Mason", description: "Decrease stone cooldown by 10%", cost: 1, effect: "decrease_stone_cooldown", multiplier: 0.9)
    @skill_critical = Skill.create!(name: "Critical Focus", description: "Double all gains", cost: 1, effect: "critical_all_gain", multiplier: 2.0)
  end

  test "should unlock skill" do
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
