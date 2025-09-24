require "test_helper"

class UserUpdatesChannelTest < ActionCable::Channel::TestCase
  test "subscribes when current_user present" do
    user = users(:one)
    stub_connection current_user: user
    subscribe
    assert subscription.confirmed?
  end
end
