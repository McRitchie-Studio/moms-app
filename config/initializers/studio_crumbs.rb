# frozen_string_literal: true

# The crumb trail over a page header's title (studio-engine's studio/_page_header,
# rendered with crumbs: studio_crumbs(...)) walks Studio.crumbs, the engine's one
# parent map. Each page with children is named here once; a page names only its
# parent. The library and the slideshow sit under Home; the digest form and a
# book sit under the library. The home dashboard and the sign-in card carry no
# page header (README, "How it works"). to_prepare, so a development reload
# redraws the map instead of keeping a stale one.
Rails.application.config.to_prepare do
  Studio.crumbs.clear.draw do
    page :home, "Home", :root_path
    page :library, "Library", :books_path, parent: :home
  end
end
