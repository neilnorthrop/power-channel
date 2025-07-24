require "test_helper"

class GameControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Rails.application.routes.url_helpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get root_url
    assert_response :success
  end
end
