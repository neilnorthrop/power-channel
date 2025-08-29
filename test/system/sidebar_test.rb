require "application_system_test_case"

class SidebarTest < ApplicationSystemTestCase
  test "mobile sidebar toggles and closes with Escape and backdrop" do
    visit game_path

    # ensure toggle is present and click it (mobile behavior)
    toggle = find("#sidebar-toggle", visible: :all)
    toggle.click

    # sidebar should be visible (aria-hidden=false)
    sidebar = find("#sidebar", visible: :all)
    assert_equal "false", sidebar["aria-hidden"]

    # pressing Escape closes the sidebar
    find("body").send_keys(:escape)
    sleep 0.2 # allow transition
    assert_equal "true", sidebar["aria-hidden"]

    # reopen and click backdrop to close
    toggle.click
    assert_equal "false", sidebar["aria-hidden"]
    find("#sidebar-backdrop", visible: :all).click
    sleep 0.2
    assert_equal "true", sidebar["aria-hidden"]
  end
end
