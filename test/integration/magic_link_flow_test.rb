require "test_helper"

# [integration] The magic-link click, end to end, through this app's real
# router — request a link, land on the short /l/<token>, and sign in.
#
# This is the test the adoption PROMISED and did not deliver. The task's
# test_plan listed "[integration] magic link signs in through /l/token", and
# dor-check credited the integration tier from the full-suite line, so the
# assertion was never actually required. The guard that DID ship
# (engine_bump_guard_test.rb) covers the TABLE, not the click — and this app is
# not in studio-engine's consumer-CI matrix, so nothing upstream exercises the
# flow either. Without this file, "magic links work here" was an untested claim
# about a live public site.
class MagicLinkFlowTest < ActionDispatch::IntegrationTest
  EMAIL = "reader@example.com"

  # The operator-visible half: what actually arrives in the email is SHORT.
  test "requesting a link mints a short /l/<token> URL" do
    assert_difference -> { Studio::Link.magic_links.count }, 1 do
      post magic_link_request_path, params: { email: EMAIL }
    end

    link = Studio::Link.magic_links.order(:id).last
    assert_equal EMAIL, link.email
    assert_match(/\A[A-Za-z0-9_-]{16}\z/, link.token,
                 "a house magic-link token is 16 URL-safe characters, not a signed blob")

    url = Rails.application.routes.url_helpers.link_url(token: link.token, host: "example.com")
    assert_equal "/l/#{link.token}", URI.parse(url).path
  end

  # Scanner safety. Outlook SafeLinks, the Gmail image proxy and link-preview
  # fetchers all GET an emailed URL; if that burned the token, the human's first
  # real click would already be dead.
  test "a prefetching scanner does not spend the link" do
    link = Studio::Link.create_magic_link(email: EMAIL)

    get link_path(token: link.token)

    assert_response :success
    assert_nil session[Studio.session_key], "the GET must not sign anyone in"
    assert_nil link.reload.consumed_at, "the GET must not burn the token"
  end

  test "the POST signs the recipient in and burns the token" do
    link = Studio::Link.create_magic_link(email: EMAIL)

    post link_consume_path(token: link.token)

    user = User.find_by(email: EMAIL)
    refute_nil user, "create-or-login makes the account on first click"
    assert_equal user.id, session[Studio.session_key]
    refute_nil link.reload.consumed_at, "a single-use token must burn"
  end

  # The behavior this whole line of work was about: a second click must not cost
  # the visitor their session. Engine >= 0.31 makes a spent link a quiet
  # redirect for the person who already used it.
  test "clicking your own link a second time leaves the session alone" do
    link = Studio::Link.create_magic_link(email: EMAIL)
    post link_consume_path(token: link.token)
    signed_in_as = session[Studio.session_key]
    refute_nil signed_in_as

    post link_consume_path(token: link.token)

    assert_equal signed_in_as, session[Studio.session_key],
                 "a spent link of your own must not log you out"
    refute_equal login_path, URI.parse(response.location).path,
                 "and must not dump you on the sign-in page"
  end

  # A spent token must still get a STRANGER nowhere — the forwarded-email case.
  test "a spent token gets a fresh visitor nowhere" do
    link = Studio::Link.create_magic_link(email: EMAIL)
    post link_consume_path(token: link.token)
    reset!

    post link_consume_path(token: link.token)

    assert_nil session[Studio.session_key], "a replayed token must not sign a stranger in"
  end

  test "an off-origin return_to is dropped rather than followed" do
    link = Studio::Link.create_magic_link(email: EMAIL, return_to: "https://evil.test/steal")

    post link_consume_path(token: link.token)

    assert_equal "/", URI.parse(response.location).path,
                 "an absolute URL must collapse to the safe default"
  end
end
