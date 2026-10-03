# frozen_string_literal: true

require "test_helper"

# [component] Moms App ends its public pages with the studio-engine site footer
# (studio-engine >= 0.84, docs/SITE_FOOTER.md), declared in
# config/initializers/studio.rb.
#
# The footer's rules belong to the engine and are tested there. What only this
# repo can assert is the adoption: the layout renders it, it carries this app's
# own links, and it carries none of what a family site must not publish (no
# address, no map, no phone, no email, no social profiles, no booking).
class SiteFooterTest < ActionDispatch::IntegrationTest
  FOOTER = "footer[data-site-footer]"
  PUBLIC_PAGES = %w[/ /books /slideshow].freeze

  test "every public page ends with the engine footer" do
    PUBLIC_PAGES.each do |path|
      get path
      assert_response :success
      assert_select FOOTER, 1, "#{path} should render exactly one site footer"
    end
  end

  test "the footer carries the brand, the tagline and the navbar's links" do
    get root_path

    assert_select "#{FOOTER} .ftr-brand" do
      assert_select "a.ftr-home[href='/']"
      assert_select ".ftr-wordmark", text: "MomsApp"
      assert_select ".ftr-wordmark-accent", text: "App"
      assert_select "img[src*='logo']", 1
      assert_select ".ftr-tagline", text: "Mom's photos and a little library of public-domain audiobooks."
    end

    assert_select "#{FOOTER} nav.ftr-col[aria-label='Explore']" do
      assert_select "h2.ftr-heading", text: "Explore"
      assert_select "a.ftr-link", 3
      assert_select "a.ftr-link[href='/']", text: "Home"
      assert_select "a.ftr-link[href='/slideshow']", text: "Photos"
      assert_select "a.ftr-link[href='/books']", text: "Library"
    end

    assert_select "#{FOOTER} .ftr-copyright", text: "© #{Time.current.year} Moms App"
  end

  test "the footer publishes no address, map, phone, email, socials or booking" do
    get root_path
    footer = css_select(FOOTER).first
    assert footer, "the footer must render for this assertion to mean anything"
    html = footer.to_html

    assert_select "#{FOOTER} [data-footer-location]", 0
    assert_select "#{FOOTER} [data-footer-map]", 0
    assert_select "#{FOOTER} address", 0
    assert_select "#{FOOTER} .ftr-email", 0
    assert_select "#{FOOTER} .ftr-socials", 0
    assert_select "#{FOOTER} a[href^='tel:']", 0
    assert_select "#{FOOTER} a[href^='mailto:']", 0
    assert_select "[data-booking-popup]", 0
    # The footer's inline stylesheet mentions Leaflet classes; what must be absent
    # is anything that would REQUEST it: a script, a stylesheet, or the map's
    # data-leaflet-js pointer.
    assert_select "script[src*='leaflet'], link[href*='leaflet'], [data-leaflet-js]", 0
    assert_not_includes html, "Location"
  end

  # A legal line would mean pages this site does not publish.
  test "the footer has no legal line" do
    get root_path

    assert_select FOOTER, 1 # or the absence below proves nothing
    assert_select "#{FOOTER} .ftr-legal a", 0
  end
end
