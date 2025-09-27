require "test_helper"

class UserActionTest < ActiveSupport::TestCase
  test "off_cooldown? returns true when cooldown is nil" do
    ua = user_actions(:one)
    ua.update!(last_performed_at: Time.current)
    ua.action.update!(cooldown: nil)

    assert ua.off_cooldown?, "Expected action with nil cooldown to allow immediate reuse"
  end

  test "off_cooldown? respects positive cooldown" do
    travel_to Time.current do
      ua = user_actions(:two)
      ua.action.update!(cooldown: 60)
      ua.update!(last_performed_at: Time.current)

      assert_not ua.off_cooldown?, "Expected cooldown to prevent reuse immediately"

      travel 61.seconds
      assert ua.off_cooldown?, "Expected cooldown to expire after duration"
    end
  end
end
