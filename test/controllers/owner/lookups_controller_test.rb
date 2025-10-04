# frozen_string_literal: true

require "test_helper"

class Owner::LookupsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(email: "owner@example.com", password: "password", role: :owner)
    sign_in @owner, scope: :user
  end

  test "suggest returns item names" do
    Item.create!(name: "Iron", description: "Iron ingot")
    Item.create!(name: "Iron Ore", description: "Ore")
    get "/owner/lookups/suggest", params: { type: "Item", q: "iron" }
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "Item", body["type"]
    assert_includes body["results"], "Iron"
    assert_includes body["results"], "Iron Ore"
  end

  test "exists true for resource and false for missing" do
    Resource.create!(name: "Wood")
    get "/owner/lookups/exists", params: { type: "Resource", name: "Wood" }
    assert_response :success
    assert_equal true, JSON.parse(@response.body)["exists"]

    get "/owner/lookups/exists", params: { type: "Resource", name: "Nope" }
    assert_response :success
    assert_equal false, JSON.parse(@response.body)["exists"]
  end

  test "exists checks flag by slug" do
    Flag.create!(slug: "early-access", name: "Early Access")
    get "/owner/lookups/exists", params: { type: "Flag", name: "early-access" }
    assert_response :success
    assert_equal true, JSON.parse(@response.body)["exists"]
  end
end
