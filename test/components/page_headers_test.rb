require "test_helper"

# [component] Task moms-app-standard-page-headers (Alex McRitchie, "run the UI
# cleanup for all the apps"): the library, the digest form, a book and the
# slideshow render studio-engine's studio/_page_header with a crumb trail from the
# app's parent map (config/initializers/studio_crumbs.rb) and its title as the
# page's one h1, inside <main>. The home dashboard (h2 sections; the navbar brand
# is its h1) and the sign-in card keep their own headings and carry no header row.
class PageHeadersTest < ActionDispatch::IntegrationTest
  ROW = ".page-header".freeze

  def sign_in_as(role)
    user = User.create!(email: "#{role}@example.com", name: role.capitalize, role: role)
    post link_consume_path(token: Studio::Link.create_magic_link(email: user.email).token)
    user
  end

  def book
    @book ||= Book.create!(title: "The Adventures of Sherlock Holmes", author: "Arthur Conan Doyle",
                           status: "failed", error_message: "test", source_url: "https://librivox.org")
  end

  def assert_standard_header(name, title, ancestors, current: title)
    assert_equal 1, css_select(ROW).size, "#{name}: one engine page header"
    assert_equal [ title ], css_select("h1").map { |h1| h1.text.strip }, "#{name}: one h1, the header's title"
    assert_select "main > #{ROW} h1.page-header-title", { text: title, count: 1 }, "#{name}: the row is a direct child of <main>"
    assert_equal ancestors, css_select("#{ROW} nav.page-header-crumbs a.page-header-crumb").map { |a| a.text.strip },
                 "#{name}: the crumb trail"
    assert_select "#{ROW} .page-header-crumb-current[aria-current=page]", { text: current, count: 1 }, name
    assert_select "#{ROW} a.page-header-parent", 1
    assert_select "header h1", { count: 0 }, "#{name}: the navbar brand is not an h1 here"
  end

  def assert_unique_ids(name)
    ids = css_select("[id]").map { |el| el["id"] }
    assert_equal ids.uniq, ids, "#{name}: duplicate ids #{ids.tally.select { |_, n| n > 1 }.keys}"
  end

  test "[component] the library renders the page header under Home, with no action for a visitor" do
    get books_path
    assert_response :success
    assert_standard_header("library", "Your Library", [ "Home" ], current: "Library")
    assert_select "#{ROW} a.page-header-crumb[href='/']", 1
    assert_select "#{ROW} .page-header-action", 0
    assert_unique_ids("library")
  end

  test "[component] an admin's library carries Digest a book as the header's one action" do
    sign_in_as("admin")
    book # a non-empty library, so the empty state's own digest link is absent
    get books_path
    assert_standard_header("library", "Your Library", [ "Home" ], current: "Library")
    assert_select "#{ROW} a.page-header-action[href=?]", new_book_path, { text: "Digest a book", count: 1 }
    assert_select "a[href=?]", new_book_path, 1
  end

  test "[component] the digest form renders the page header under Library" do
    sign_in_as("admin")
    get new_book_path
    assert_response :success
    assert_standard_header("digest", "Digest a book", [ "Home", "Library" ])
    assert_select "#{ROW} a.page-header-parent[href=?]", books_path
    assert_select "a", { text: /← Library/, count: 0 }, "the crumb replaces the old back link"
    assert_select "form"
    assert_unique_ids("digest")
  end

  test "[component] a book renders its title as the page header under Library" do
    get book_path(book.slug)
    assert_response :success
    assert_standard_header("book", book.title, [ "Home", "Library" ])
    assert_select "a", { text: /← Library/, count: 0 }, "the crumb replaces the old back link"
    assert_select "p", text: "by Arthur Conan Doyle"
    assert_unique_ids("book")
  end

  test "[component] the slideshow renders the page header under Home" do
    get slideshow_path
    assert_response :success
    assert_standard_header("slideshow", "Mom's Photos", [ "Home" ])
    assert_select "[data-carousel-target=track].carousel-track:not([style])", 1
    assert_unique_ids("slideshow")
  end

  test "[component] home keeps its sections, with the navbar brand as its one h1" do
    get root_path
    assert_response :success
    assert_select ROW, 0
    assert_select "h1", 1
    assert_select "header h1", text: /Moms\s+App/
    assert_select "main h2", minimum: 2
    assert_select "[data-carousel-target=track].carousel-track:not([style])", 1
    assert_unique_ids("home")
  end

  test "[component] the sign-in card keeps its own heading and carries no header row" do
    get login_path
    assert_response :success
    assert_select ROW, 0
    assert_select "h1", 1
    assert_select "main h1", text: /Moms\s+App/
    assert_select "header h1", 0
  end
end
