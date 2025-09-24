# frozen_string_literal: true

require "test_helper"

class EnsureFlagsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @user.user_flags.destroy_all
    @item_a = Item.create!(name: "ItemA")
    @item_b = Item.create!(name: "ItemB")
    @item_c = Item.create!(name: "ItemC")
    @camp = Building.create!(name: "Scout Camp", level: 1)

    @flag = Flag.create!(slug: "or_flag", name: "OR Flag")
    # OR alternatives: A or B or C
    FlagRequirement.create!(flag: @flag, requirement_type: "Item", requirement_id: @item_a.id, quantity: 1, logic: "OR")
    FlagRequirement.create!(flag: @flag, requirement_type: "Item", requirement_id: @item_b.id, quantity: 1, logic: "OR")
    FlagRequirement.create!(flag: @flag, requirement_type: "Item", requirement_id: @item_c.id, quantity: 1, logic: "OR")

    @flag_and_or = Flag.create!(slug: "and_or_flag", name: "AND+OR Flag")
    FlagRequirement.create!(flag: @flag_and_or, requirement_type: "Building", requirement_id: @camp.id, quantity: 1, logic: "AND")
    FlagRequirement.create!(flag: @flag_and_or, requirement_type: "Item", requirement_id: @item_a.id, quantity: 1, logic: "OR")
    FlagRequirement.create!(flag: @flag_and_or, requirement_type: "Item", requirement_id: @item_b.id, quantity: 1, logic: "OR")
  end

  test "awards flag when any OR requirement satisfied" do
    # Give user ItemB only
    @user.user_items.find_or_create_by(item: @item_b).update(quantity: 1)

    # Touch relevant items to limit candidate scan
    EnsureFlagsService.evaluate_for(@user, touch: { items: [ @item_b.id ] })

    assert @user.user_flags.exists?(flag_id: @flag.id), "Expected OR flag to be awarded"
  end

  test "does not award flag when no OR requirement satisfied" do
    EnsureFlagsService.evaluate_for(@user, touch: { items: [ 0 ] })
    assert_not @user.user_flags.exists?(flag_id: @flag.id)
  end

  test "requires all AND and any OR when mixed" do
    # Has ItemA but no building yet -> should not award
    @user.user_items.find_or_create_by(item: @item_a).update(quantity: 1)
    EnsureFlagsService.evaluate_for(@user, touch: { items: [ @item_a.id ] })
    assert_not @user.user_flags.exists?(flag_id: @flag_and_or.id)

    # Grant building level 1 and re-evaluate -> should award
    UserBuilding.create!(user: @user, building: @camp, level: 1)
    EnsureFlagsService.evaluate_for(@user, touch: { buildings: [ @camp.id ] })
    assert @user.user_flags.exists?(flag_id: @flag_and_or.id)
  end
end
