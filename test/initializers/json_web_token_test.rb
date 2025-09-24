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
end
