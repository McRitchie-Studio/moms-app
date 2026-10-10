require "application_system_test_case"

# [system] The front door in a real browser: what only running JavaScript
# proves. The markup hooks are asserted in test/integration.
class HomeTest < ApplicationSystemTestCase
  test "Next scrolls the carousel" do
    visit root_path

    assert_equal 0, track_scroll_left, "precondition: the track starts unscrolled"

    click_button "Next ›"

    assert_track_scrolls
  end

  test "Prev from the start goes around to the end" do
    visit root_path

    click_button "‹ Prev"

    assert_track_scrolls
  end

  test "the carousel advances on its own" do
    visit root_path

    assert_selector "[data-carousel-target=toggle]", text: "Pause"
    assert_track_scrolls within: 6
  end

  test "the pointer pauses the carousel and leaving resumes it" do
    visit root_path

    find("[data-controller=carousel]").hover
    assert_selector "[data-carousel-target=toggle]", text: "Play"

    find("header").hover
    assert_selector "[data-carousel-target=toggle]", text: "Pause"
  end

  # A scripted click sends no mouseenter, so the hover pause stays out of it.
  test "the toggle button pauses and plays" do
    visit root_path
    assert_selector "[data-carousel-target=toggle]", text: "Pause"

    page.execute_script("document.querySelector('[data-carousel-target=toggle]').click()")
    assert_selector "[data-carousel-target=toggle]", text: "Play"
    left = track_scroll_left
    sleep 3.5
    assert_equal left, track_scroll_left, "a paused carousel moved"

    page.execute_script("document.querySelector('[data-carousel-target=toggle]').click()")
    assert_selector "[data-carousel-target=toggle]", text: "Pause"
  end

  test "the navbar takes its shadow once the page has scrolled" do
    page.current_window.resize_to(500, 600)
    visit root_path

    assert_no_selector "header.shadow-lg"

    page.execute_script("window.scrollTo(0, 200)")
    assert_selector "header.shadow-lg.border-b.border-subtle"

    page.execute_script("window.scrollTo(0, 0)")
    assert_no_selector "header.shadow-lg"
    assert_no_selector "header.border-b"
  end

  test "the public root renders both sections for a signed-out visitor" do
    visit root_path

    assert_selector "h2", text: "Mom's Photos"
    assert_selector "h2", text: "The Library"
  end

  test "the root does not bounce a signed-out visitor to sign in" do
    visit root_path

    assert_current_path root_path
  end

  private

  def track_scroll_left
    page.evaluate_script("document.querySelector('[data-carousel-target=track]').scrollLeft").to_f
  end

  # The track scrolls smoothly, so poll.
  def assert_track_scrolls(within: Capybara.default_max_wait_time)
    deadline = Time.now + within
    sleep 0.05 while track_scroll_left <= 0 && Time.now < deadline

    assert_operator track_scroll_left, :>, 0, "expected the track to scroll"
  end
end
