require "test_helper"

# [integration] The pages link the Tailwind build that application.css makes
# through studio-engine's host.css (task satellites-adopt-css-first-tailwind),
# and every /assets URL a page names is served. The build must carry one probe
# class for each thing it depends on:
#   .text-heading   the engine's theme tokens (engine.css's theme). This app's
#                   own views use it too (books/index, pages/index ...), so it
#                   proves the theme is imported, not any scan.
#   .btn-primary    the engine's component @utility layer. This app's own views
#                   use it (books/index, books/new, sessions/new), so it is
#                   app-used here: it proves the layer is imported, not that
#                   the engine's views are scanned.
#   .animate-spin   the engine view scan (host.css's @source lines). Only
#                   studio-engine's views name it (studio/modals/blocks/
#                   _processing_card, error_logs/index, style/_modals,
#                   components/_theme_toggle_morph, solana_sessions/
#                   phantom_callback); nothing else in this repo does and no
#                   engine CSS declares it, so it compiles only when Tailwind
#                   reaches those views. If this app's code ever uses it, pick
#                   another engine-only class.
#   .spinner        the engine's motion layer (engine-motion.css). It is plain
#                   CSS, emitted on import alone: it proves the import, not any
#                   scan.
# application.css declares no @theme of its own, so unlike alex-build and
# commercial-welding there is no app-palette probe here.
# Tailwind v4 scans this repo's test/ too. It skips Ruby # comments, so naming
# the classes here is safe, but it picks up a class written as a code literal:
# a literal probe in the code below would compile because this file names it,
# and pass whatever the engine scan does. So the code spells each probe as
# words joined with "-" at runtime.
class TailwindAssetsTest < ActionDispatch::IntegrationTest
  PROBES = [ %w[text heading], %w[btn primary], %w[animate spin], %w[spinner] ]
           .map { |words| words.join("-") }.freeze

  test "the home page names only assets that are served" do
    get root_path
    assert_response :success
    assert_every_asset_served
  end

  test "a signed-in page names only assets that are served" do
    admin = User.create!(email: "admin@example.com", name: "Admin", role: "admin")
    post link_consume_path(token: Studio::Link.create_magic_link(email: admin.email).token)
    get new_book_path
    assert_response :success
    assert_every_asset_served
  end

  test "the linked Tailwind build carries the engine's tokens, components, scanned views and motion" do
    get root_path
    href = asset_urls.find { |url| url.match?(%r{\A/assets/tailwind-[0-9a-f]+\.css\z}) }
    assert href, "the layout must link the Tailwind build"

    get href
    assert_response :success
    css = response.body.delete(" \n")
    lost = PROBES.reject { |probe| css.include?(".#{probe}{") }
    assert_empty lost, "the Tailwind build lost #{lost.map { |probe| ".#{probe}" }.join(", ")}"
  end

  private

  def asset_urls
    Nokogiri::HTML(response.body).css("link[href], script[src], img[src], source[src]")
            .map { |node| node["href"] || node["src"] }
            .select { |url| url.start_with?("/assets/") }
            .uniq
  end

  def assert_every_asset_served
    urls = asset_urls
    assert urls.any? { |url| url.start_with?("/assets/tailwind-") }, "the page must link the Tailwind build"
    urls.each do |url|
      get url
      assert_response :success, "#{url} is named by the page but not served"
    end
  end
end
