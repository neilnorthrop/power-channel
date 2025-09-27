# frozen_string_literal: true

require "test_helper"

class JsonWebTokenTest < ActiveSupport::TestCase
  test "raises in production when secret missing" do
    skip "Production-only behavior; skip if running with configured secret in production" if Rails.env.production?
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))
    Rails.application.config.stubs(:jwt_secret).returns(nil)
    assert_raises RuntimeError do
      JsonWebToken.encode(user_id: 123)
    end
  end

  test "encodes and decodes with HS256 and verifies exp" do
    payload = { user_id: 42, role: "tester" }
    token = JsonWebToken.encode(payload, 10.minutes.from_now)
    decoded = JsonWebToken.decode(token)
    assert_equal 42, decoded[:user_id]
    assert_equal "tester", decoded[:role]
    assert decoded[:exp].is_a?(Integer)
  end

  test "expired token raises JWT::ExpiredSignature" do
    token = JsonWebToken.encode({ user_id: 9 }, 1.second.ago)
    assert_raises JWT::ExpiredSignature do
      JsonWebToken.decode(token)
    end
  end

  test "tampered token fails verification" do
    token = JsonWebToken.encode({ user_id: 7 })
    tampered = token.reverse # naive tamper
    assert_raises JWT::DecodeError do
      JsonWebToken.decode(tampered)
    end
  end
end
