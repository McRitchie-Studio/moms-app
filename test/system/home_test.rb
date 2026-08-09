require "application_system_test_case"

# [system] The front door, in a real browser.
#
# CI has run a `system-test` job since the app was scaffolded, and the Gemfile
# has carried capybara + selenium-webdriver the whole time — but `test/system`
# and `application_system_test_case.rb` were never created, so the job died on
# `cannot load such file -- test/system` without running anything. This is the
# lane's first real content.
#
# These assertions are chosen to be ones the cheaper tiers CANNOT make.
# `test/integration/home_smoke_test.rb` already asserts the server-rendered
# markup and the `x-data="karenSlideshow()"` hook, so re-asserting markup here
# would just duplicate it at many times the runtime. What only a browser proves
# is that the JavaScript actually RUNS.
class HomeTest < ApplicationSystemTestCase
  test "the carousel is genuinely interactive, not just wired in the markup" do
    visit root_path

    assert_equal 0, track_scroll_left, "precondition: the track starts unscrolled"

    # next() moves the track by scripting scrollLeft. Nothing in the server
    # response can do that, so a passing assertion here proves Alpine actually
    # booted and its handler ran — which is the only thing this tier can prove
    # that the integration tier cannot.
    #
    # Deliberately NOT the Pause/Play text: the wrapper carries
    # @mouseenter="stop()", so Capybara's click is preceded by a hover that
    # already stopped the timer, and toggle() then restarts it — the label nets
    # back to "Pause" and the assertion fails for a reason that has nothing to
    # do with whether JS is alive.
    click_button "Next ›"

    assert_scrolled
  end

  test "the public root renders both sections for a signed-out visitor" do
    visit root_path

    assert_selector "h2", text: "Mom's Photos"
    assert_selector "h2", text: "The Library"
  end

  # The root skips authentication on purpose (PagesController#index). If that
  # ever regresses, the family site starts demanding a login — assert we land on
  # the root itself, not a redirect to sign-in.
  test "the root does not bounce a signed-out visitor to sign in" do
    visit root_path

    assert_current_path root_path
  end

  private

  def track_scroll_left
    page.evaluate_script("document.querySelector('[x-ref=track]').scrollLeft")
  end

  # scroll-smooth animates, so poll rather than sampling once.
  def assert_scrolled
    deadline = Time.now + Capybara.default_max_wait_time
    sleep 0.05 while track_scroll_left.to_f <= 0 && Time.now < deadline

    assert_operator track_scroll_left.to_f, :>, 0,
                    "expected the track to scroll — Alpine did not run"
  end
end
