require "test_helper"

# [integration] Public signup is closed (app/controllers/concerns/closed_signup.rb).
#
# Every door through which studio-engine makes an account is driven here twice,
# through this app's real router: once as a STRANGER, who must leave no User row
# behind, and once as a MEMBER, who must sign in as before. The stranger half is
# the task; the member half is what keeps the gate from being a wall.
#
# Each stranger test was watched failing with its gate removed (see the task's
# checks); `the doors really do create accounts when the gate is off` keeps that
# control inside the suite for the door where it matters most.
class ClosedSignupTest < ActionDispatch::IntegrationTest
  MEMBER   = "mom@example.com"
  STRANGER = "stranger@example.com"

  setup do
    @member = User.create!(email: MEMBER, name: "Mom")
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  # ---- /signup ---------------------------------------------------------------

  test "GET /signup offers no form: it sends the visitor to sign-in" do
    get "/signup"

    assert_redirected_to "/login"
    follow_redirect!
    assert_response :success
    assert_select "form[action='/signup']", false
  end

  test "POST /signup creates nothing, mints nothing and mails nothing" do
    assert_nothing_made do
      post "/signup", params: { user: { name: "Stranger", email: STRANGER } }
    end

    assert_redirected_to "/login"
  end

  test "POST /signup is closed to a member's address too: it is not a sign-in door" do
    assert_nothing_made { post "/signup", params: { user: { email: MEMBER } } }
  end

  # ---- POST /magic_link ------------------------------------------------------

  test "a magic-link request for an unknown address mints and mails nothing" do
    assert_nothing_made { post magic_link_request_path, params: { email: STRANGER } }
  end

  test "a magic-link request for a member still mints and mails one link" do
    assert_difference -> { Studio::Link.magic_links.count } => 1, -> { Studio::EmailDelivery.count } => 1 do
      post magic_link_request_path, params: { email: MEMBER }
    end

    assert_equal MEMBER, Studio::Link.magic_links.order(:id).last.email
  end

  test "a member is recognized however the address is typed" do
    assert_difference -> { Studio::Link.magic_links.count }, 1 do
      post magic_link_request_path, params: { email: "  Mom@Example.COM " }
    end
  end

  # No account enumeration: whatever a visitor can read back must be the same
  # for an address with an account and one without.
  test "the response to an unknown address is indistinguishable from a member's" do
    # Frozen so the page's own issued-at stamp is not the one difference found.
    known, unknown = freeze_time { [ magic_link_response(MEMBER), magic_link_response(STRANGER) ] }

    assert_equal known, unknown
    assert_equal 302, known[:status]
    assert_match(/check your inbox/i, known[:flash]["notice"], "the comparison must be of a real answer")
    assert_match(/check your inbox/i, known[:landing], "and the page it lands on must carry it")
  end

  test "the JSON response to an unknown address is indistinguishable too" do
    known   = magic_link_response(MEMBER, as: :json)
    unknown = magic_link_response(STRANGER, as: :json)

    assert_equal known, unknown
    assert_equal({ "success" => true }, JSON.parse(known[:body]))
  end

  # The clock is part of the response. A stranger's request does almost no work,
  # so without the floor it returns in a few milliseconds and a member's does not.
  test "a stranger's request is held to the same floor as a member's" do
    with_response_floor(0.25) do
      assert_operator seconds { post magic_link_request_path, params: { email: STRANGER } }, :>=, 0.25
      assert_operator seconds { post magic_link_request_path, params: { email: MEMBER } }, :>=, 0.25
    end

    assert_operator seconds { post magic_link_request_path, params: { email: STRANGER } }, :<, 0.25,
                    "control: with the floor off the stranger's answer is fast, so the floor is what held it"
  end

  test "the floor is on outside the test environment" do
    with_response_floor(nil) { assert_equal 0.4, ClosedSignup.response_floor }
  end

  # ---- POST /login: no passwords here, one answer for everyone ---------------

  # studio-engine draws POST /login only for an app with :password in
  # auth_methods (0.91, engine PR 420), and this app has none, so the route is
  # undrawn: a 404 for everyone, and no code of this app or the engine reads the
  # address. Adding :password would draw it again, and without a password column
  # the engine action would answer a member with a 500 and a stranger with a 422.
  test "POST /login is undrawn: a member and a stranger get the same 404, and nothing raises" do
    assert_not login_route_drawn?, "POST /login is drawn; this app has no passwords (config/initializers/studio.rb auth_methods)"

    member_answer = stranger_answer = nil
    assert_no_difference -> { ErrorLog.count } do
      member_answer = login_response(MEMBER)
      stranger_answer = login_response(STRANGER)
    end

    # The test environment renders a 404 as Rails' debug page, whose object ids
    # differ per request; production serves public/404.html to both. Everything
    # else must match.
    assert_equal member_answer.except(:body), stranger_answer.except(:body)
    assert_equal 404, member_answer[:status]
    assert_nil member_answer[:location]
  end

  test "POST /login signs nobody in, even with a member's address" do
    post "/login", params: { email: MEMBER, password: "anything" }
    get root_path

    assert_nil session[Studio.session_key]
  end

  # ---- POST /magic_link: rate limited per client ----------------------------

  test "magic-link requests past the limit are refused, and the refusal mails nothing" do
    ClosedSignup::MagicLinkRequest::LIMIT.times { post magic_link_request_path, params: { email: STRANGER } }

    assert_no_difference [ -> { Studio::Link.count }, -> { Studio::EmailDelivery.count } ] do
      post magic_link_request_path, params: { email: MEMBER }
    end
    assert_redirected_to login_path
    assert_match(/Too many sign-in requests/, flash[:alert])

    post magic_link_request_path, params: { email: MEMBER }, as: :json
    assert_response :too_many_requests
  end

  test "the limit refuses a member's address and a stranger's alike" do
    limit = ClosedSignup::MagicLinkRequest::LIMIT
    limit.times { post magic_link_request_path, params: { email: MEMBER } }
    post magic_link_request_path, params: { email: STRANGER }
    stranger_refusal = [ response.status, response.location, flash[:alert] ]

    ClosedSignup::MagicLinkRequest::STORE.clear
    limit.times { post magic_link_request_path, params: { email: STRANGER } }
    post magic_link_request_path, params: { email: MEMBER }

    assert_equal stranger_refusal, [ response.status, response.location, flash[:alert] ]
    assert_match(/Too many sign-in requests/, flash[:alert])
  end

  # The counters are database rows, not process memory. A second Puma worker, a
  # second dyno, or the process after a deploy holds its own SolidCache::Store;
  # requests it counted must spend this process's limit too. Rails' rate_limit
  # keys a counter "rate-limit:<scope>:<name>:<client address>".
  test "the limit holds across processes: counts another store made are honored" do
    other_process = SolidCache::Store.new
    key = "rate-limit:closed_signup:closed_signup_magic_link:127.0.0.1"
    ClosedSignup::MagicLinkRequest::LIMIT.times { other_process.increment(key, 1, expires_in: 15.minutes) }

    assert_no_difference -> { Studio::Link.count } do
      post magic_link_request_path, params: { email: MEMBER }
    end
    assert_match(/Too many sign-in requests/, flash[:alert])
  end

  test "[unit] the rate-limit store is shared: two stores read one count" do
    key = "closed-signup-shared-store-check"
    ClosedSignup::MagicLinkRequest::STORE.increment(key, 1, expires_in: 1.minute)

    assert_equal 2, SolidCache::Store.new.increment(key, 1, expires_in: 1.minute)
    assert_equal 2, ClosedSignup::MagicLinkRequest::STORE.read(key, raw: true).to_i
  end

  test "[unit] the rate-limit store caps its table at 16 MB" do
    assert_equal 16.megabytes, ClosedSignup::MagicLinkRequest::STORE.max_size
  end

  test "the limit counts each client address on its own" do
    ClosedSignup::MagicLinkRequest::LIMIT.times do
      post magic_link_request_path, params: { email: STRANGER }, headers: { "REMOTE_ADDR" => "198.51.100.1" }
    end

    assert_difference -> { Studio::Link.magic_links.count } => 1 do
      post magic_link_request_path, params: { email: MEMBER }, headers: { "REMOTE_ADDR" => "198.51.100.2" }
    end
  end

  # The Heroku router appends the address it saw to X-Forwarded-For and never
  # sets Forwarded, so a client-written Forwarded header must not choose the
  # address the limit counts (config/initializers/forwarded_headers.rb).
  test "a client-written Forwarded header does not reset the limit" do
    ClosedSignup::MagicLinkRequest::LIMIT.times do |i|
      post magic_link_request_path, params: { email: STRANGER },
                                    headers: heroku_headers.merge("Forwarded" => "for=203.0.113.#{i + 1}")
    end

    assert_no_difference -> { Studio::Link.count } do
      post magic_link_request_path, params: { email: MEMBER },
                                    headers: heroku_headers.merge("Forwarded" => "for=203.0.113.99")
    end
    assert_match(/Too many sign-in requests/, flash[:alert])
  end

  # ---- the sign-in email ----------------------------------------------------

  test "the sign-in email no longer promises to create an account" do
    mail = UserMailer.magic_link(MEMBER, "tok123").message
    parts = mail.multipart? ? [ mail.text_part, mail.html_part ].compact : [ mail ]
    text = parts.map { |part| part.body.decoded }.join("\n")

    assert_includes text, "/l/tok123", "the mail did not render its link, so the copy check would prove nothing"
    refute_match(/create one for you/i, text)
    assert_match(/No password needed/i, text)
  end

  # The HTML body comes from the email catalog, not a view. An operator's saved
  # wording on /admin/emails still wins over this default.
  test "the email catalog's default body makes no account promise either" do
    body = Studio::EmailCatalog.body(:magic_link)

    refute_match(/create one for you/i, body)
    assert_includes body, "No password needed"
  end

  # ---- POST /l/<token> -------------------------------------------------------

  # A link for a stranger can no longer be requested, but one minted before the
  # gate shipped (or by hand) must not become an account on click.
  test "clicking a link for an unknown address creates no account and no session" do
    link = Studio::Link.create_magic_link(email: STRANGER)

    assert_no_difference -> { User.count } do
      post link_consume_path(token: link.token)
    end

    assert_redirected_to "/login"
    assert_equal ClosedSignup::MESSAGE, flash[:alert]
    assert_nil session[Studio.session_key]
    refute_nil link.reload.consumed_at, "the token still burns: it cannot be replayed"
  end

  test "a member signs in by magic link exactly as before" do
    post magic_link_request_path, params: { email: MEMBER }
    link = Studio::Link.magic_links.order(:id).last

    assert_no_difference -> { User.count } do
      post link_consume_path(token: link.token)
    end

    assert_equal @member.id, session[Studio.session_key]
    assert_redirected_to "/"
  end

  # ---- Google ----------------------------------------------------------------

  test "an unknown Google account is refused with a plain message and creates nothing" do
    mock_google(email: STRANGER, uid: "g-stranger")

    assert_no_difference -> { User.count } do
      post "/auth/google_oauth2"
      follow_redirect!
    end

    assert_redirected_to "/login"
    assert_equal ClosedSignup::MESSAGE, flash[:alert]
    assert_nil session[Studio.session_key]
    follow_redirect!
    assert_includes response.body, "private family site"
  end

  test "a member signs in with Google by address, and the Google id is linked" do
    mock_google(email: MEMBER, uid: "g-mom")

    assert_no_difference -> { User.count } do
      post "/auth/google_oauth2"
      follow_redirect!
    end

    assert_equal @member.id, session[Studio.session_key]
    assert_redirected_to "/"
    assert_equal %w[google_oauth2 g-mom], @member.reload.values_at(:provider, :uid)
  end

  test "a member signs in with an already linked Google id" do
    @member.update!(provider: "google_oauth2", uid: "g-mom")
    mock_google(email: "renamed@example.com", uid: "g-mom")

    assert_no_difference -> { User.count } do
      post "/auth/google_oauth2"
      follow_redirect!
    end

    assert_equal @member.id, session[Studio.session_key]
  end

  # ---- SSO -------------------------------------------------------------------

  # Shared-cookie SSO is off for this app, so the hub's session keys are planted
  # by hand: this is the session a visitor WOULD carry if it were ever turned on.
  test "an SSO session for an unknown address creates no account" do
    plant_session("sso_email" => STRANGER, "sso_name" => "Stranger", "sso_source" => "McRitchie Studio")

    assert_no_difference -> { User.count } do
      post "/sso_continue"
    end

    assert_redirected_to "/login"
    assert_equal ClosedSignup::MESSAGE, flash[:alert]
    assert_nil session[Studio.session_key]
  end

  test "an SSO session for a member still continues" do
    plant_session("sso_email" => MEMBER, "sso_name" => "Mom", "sso_source" => "McRitchie Studio")

    assert_no_difference -> { User.count } do
      post "/sso_continue"
    end

    assert_equal @member.id, session[Studio.session_key]
  end

  test "POST /sso_continue with no SSO session is the engine's quiet redirect" do
    post "/sso_continue"

    assert_redirected_to "/login"
    assert_nil flash[:alert]
  end

  # ---- No way in is advertised -----------------------------------------------

  test "no page links to /signup, and the sign-in page says what the site is" do
    %w[/ /login /books /slideshow].each do |path|
      get path

      assert_response :success, path
      assert_select "a[href*='signup']", false, "#{path} must not link to /signup"
      assert_select "form[action*='signup']", false, "#{path} must not post to /signup"
      assert_no_match(/sign\s*up/i, response.body, "#{path} must not invite a sign-up")
    end

    get "/login"
    assert_select "[data-members-only]", text: /private family site/
  end

  test "the footer carries no link to /signup" do
    get "/"

    assert_select "footer a", minimum: 1
    assert_select "footer a[href*='signup']", false
  end

  test "the sign-in page still offers both methods" do
    get "/login"

    assert_select "form[action='#{magic_link_request_path}'] input[name='email']"
    assert_select "form[action='/auth/google_oauth2'][method='post']"
  end

  # ---- Control ---------------------------------------------------------------

  # The gate is what closes the door, not something else about this app or this
  # test: with the engine's own hook restored, the same click makes an account.
  test "control: without the gate, the same click creates an account" do
    link = Studio::Link.create_magic_link(email: STRANGER)
    gate = ClosedSignup::LinkClick.instance_method(:sign_up_new)
    ClosedSignup::LinkClick.send(:remove_method, :sign_up_new)

    begin
      assert_difference -> { User.count }, 1 do
        post link_consume_path(token: link.token)
      end
    ensure
      ClosedSignup::LinkClick.send(:define_method, :sign_up_new, gate)
      ClosedSignup::LinkClick.send(:private, :sign_up_new)
    end
  end

  private

  # Whether the engine draws a password sign-in for this app (only with :password).
  def login_route_drawn?
    Rails.application.routes.recognize_path("/login", method: :post)
    true
  rescue ActionController::RoutingError
    false
  end

  # What a fresh visitor reads from POST /login with this address.
  def login_response(email)
    reset!
    post "/login", params: { email: email, password: "guess" }
    { status: response.status, location: response.location, flash: flash.to_h,
      body: response.body, cookies: response.cookies.keys.sort }
  end

  # A request in the shape the Heroku router forwards: the client's address on
  # the right of X-Forwarded-For, behind a private router hop.
  def heroku_headers
    { "REMOTE_ADDR" => "10.1.2.3", "X-Forwarded-For" => "198.51.100.77" }
  end

  def assert_nothing_made(&block)
    assert_no_difference [ -> { User.count }, -> { Studio::Link.count }, -> { Studio::EmailDelivery.count } ], &block
  end

  def seconds
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  def with_response_floor(value)
    config = Rails.configuration.x.closed_signup
    before = config.response_floor
    config.response_floor = value
    yield
  ensure
    config.response_floor = before
  end

  def mock_google(email:, uid:)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid, info: { email: email, name: "Google User" }
    )
  end

  # Everything a visitor can read from one fresh-session request: the redirect,
  # the flash, the body, the headers that are not per-request noise, and the page
  # the redirect lands on.
  def magic_link_response(email, as: nil)
    reset!
    post magic_link_request_path, params: { email: email }, as: as

    seen = {
      status:  response.status,
      location: response.location,
      flash:   flash.to_h,
      body:    response.body,
      headers: response.headers.to_h.except("x-request-id", "x-runtime", "set-cookie", "etag"),
      cookies: response.cookies.keys.sort
    }
    return seen if as == :json

    follow_redirect!
    seen.merge(landing: response.body.gsub(/(authenticity_token" value=|csrf-token" content=)"[^"]*"/, "\\1\"\""))
  end

  # Start the next request with this session. The cookie is encrypted with the
  # app's own key, the same way the session store writes it.
  def plant_session(data)
    key = Rails.application.config.session_options[:key]
    request = ActionDispatch::Request.new(Rails.application.env_config.merge("HTTP_HOST" => host))
    jar = request.cookie_jar
    jar.encrypted[key] = { value: data.merge("session_id" => SecureRandom.hex(16)) }
    cookies[key] = jar[key]
  end
end
