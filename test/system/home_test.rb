require "application_system_test_case"

# [system] The front door, in a real browser.
#
# CI has run a `system-test` job since the app was scaffolded, and the Gemfile
# has carried capybara + selenium-webdriver the whole time — but `test/system`
# and `application_system_test_case.rb` were never created, so the job died on
# `cannot load such file -- test/system` rather than running anything. This is
# the lane's first real content.
#
# Kept deliberately thin: this app's value is that the root page renders for a
# signed-OUT visitor (it is a public family site), which is exactly what an
# integration test cannot prove on its own — the page is Alpine-driven, so a
# JS error would leave the markup present and the page dead.
class HomeTest < ApplicationSystemTestCase
  test "the public root renders both sections for a signed-out visitor" do
    visit root_path

    assert_selector "h2", text: "Mom's Photos"
    assert_selector "h2", text: "The Library"
    assert_link "Open slideshow →"
  end

  # The root skips authentication on purpose (PagesController#index). If that
  # ever regresses, the family site starts demanding a login — assert we land on
  # the root itself, not a redirect to sign-in.
  test "the root does not bounce a signed-out visitor to sign in" do
    visit root_path

    assert_current_path root_path
  end
end
