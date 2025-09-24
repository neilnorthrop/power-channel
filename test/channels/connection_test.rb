# frozen_string_literal: true

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection

  def test_rejects_without_token
    assert_reject_connection { connect "/cable" }
  end

  def test_connects_with_valid_token
    user = users(:one)
    token = JsonWebToken.encode(user_id: user.id)
    assert_nothing_raised do
      connect "/cable?token=#{token}"
    end
    assert_equal user, connection.current_user
  end
end
