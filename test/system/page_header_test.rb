require "application_system_test_case"

# [e2e] Task moms-app-standard-page-headers: a book's engine page header in a real
# browser, at the desktop size (1400px) and on a 390px phone. On a desktop the
# crumb trail shows; on a phone it gives way to one link to the parent, and the
# page never scrolls sideways. After a 1500px scroll the row stays pinned under
# this app's own navbar (a plain sticky <header>, which the engine's pinned stack
# measures as the nav layer).
class PageHeaderTest < ApplicationSystemTestCase
  # Headless Chrome will not shrink its window below 500px, so the phone size is
  # emulated through DevTools and the test asserts the width it really got.
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  setup do
    # failed, so the page does not reload itself; 60 chapters, so it scrolls.
    @book = Book.create!(title: "The Adventures of Sherlock Holmes", author: "Arthur Conan Doyle",
                         status: "failed", error_message: "test", source_url: "https://librivox.org")
    60.times { |i| @book.chapters.create!(position: i + 1, title: "Chapter #{i + 1}", duration_seconds: 600) }
  end

  def sideways_overflow = evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")

  def assert_pinned_after_scroll(label)
    execute_script("window.scrollTo(0, 1500)")
    assert_operator evaluate_script("window.scrollY"), :>=, 1400, "#{label}: the page really scrolled"
    gap = -> { evaluate_script(<<~JS) }
      Math.abs(Math.round(document.querySelector('.page-header').getBoundingClientRect().top -
                          document.querySelector('header').getBoundingClientRect().bottom))
    JS
    page.document.synchronize(5) { raise Capybara::ExpectationNotMet, "row #{gap.call}px off the navbar" if gap.call > 2 }
    assert_operator gap.call, :<=, 2, "#{label}: the row sticks under the navbar"
    assert_operator evaluate_script("document.querySelector('header').getBoundingClientRect().top"), :>=, -1,
                    "#{label}: the navbar itself is still on screen"
  end

  test "a book's page header at 1400px and 390px, pinned after a 1500px scroll" do
    visit book_path(@book.slug)
    assert_equal 1400, evaluate_script("window.innerWidth"), "the desktop viewport is 1400px"
    within(".page-header") do
      assert_selector "h1.page-header-title", text: @book.title
      assert_selector "nav.page-header-crumbs a.page-header-crumb", text: "Library", visible: true
      assert_no_selector "a.page-header-parent", visible: true
    end
    assert_equal 0, sideways_overflow, "overflow at 1400px"
    assert_pinned_after_scroll "1400px"

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit book_path(@book.slug)
    assert_equal 390, evaluate_script("window.innerWidth"), "the phone viewport is 390px"
    within(".page-header") do
      assert_selector "h1.page-header-title", visible: true
      assert_selector "a.page-header-parent", text: "Library", visible: true
      assert_no_selector "nav.page-header-crumbs", visible: true
    end
    assert_equal 0, sideways_overflow, "overflow at 390px"
    assert_pinned_after_scroll "390px"

    find(".page-header a.page-header-parent").click
    assert_selector ".page-header h1", text: "Your Library"
  end
end
