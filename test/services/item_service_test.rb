# frozen_string_literal: true

require "test_helper"

class ItemServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "use calls increase_luck effect" do
    item = items(:one)
    service = ItemService.new(@user, item)
    service.expects(:increase_luck)
    service.use
  end

  test "use calls reset_cooldown effect" do
    item = items(:two)
    service = ItemService.new(@user, item)
    service.expects(:reset_cooldown)
    service.use
  end
end
