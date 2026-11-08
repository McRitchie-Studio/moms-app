require "test_helper"

# [unit] Task moms-app-standard-page-headers: the app's one crumb parent map
# (config/initializers/studio_crumbs.rb) resolves each page's trail, root first,
# through studio_crumbs, the helper every page header calls.
class StudioCrumbsTest < ActionView::TestCase
  include Studio::CrumbsHelper

  test "[unit] Home is the root, and the library and the slideshow sit under it" do
    assert_empty studio_crumbs(:home)
    assert_equal [ { label: "Home", href: "/" } ], studio_crumbs(:library)
    assert_equal [ { label: "Home", href: "/" } ], studio_crumbs(parent: :home)
  end

  test "[unit] the digest form and a book sit under Library, under Home" do
    assert_equal [ { label: "Home", href: "/" }, { label: "Library", href: books_path } ],
                 studio_crumbs(parent: :library)
  end

  test "[unit] a key the map lacks raises in test, so a typo fails here" do
    assert_raises(Studio::Crumbs::UnknownPage) { studio_crumbs(:books) }
  end
end
