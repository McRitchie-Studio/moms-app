# frozen_string_literal: true

# Moms App is a private family site: nobody creates their own account.
#
# studio-engine (0.85.0, and 0.87.0 on its main) has NO setting that turns
# self-registration off. Its passwordless flows are "create-or-login" by design,
# so each of them makes a User for an address it has never seen. This module is
# the host-side gate on every one of those doors. Each sub-module is prepended
# onto one engine controller (config/initializers/closed_signup.rb) and either
# hands a MEMBER straight to the engine's own action, unchanged, or turns a
# stranger away before anything is minted, mailed or saved.
#
#   door                                   engine behavior          here
#   GET/POST /signup                       form; mails a link       not routed (config/routes.rb)
#   POST /magic_link, unknown email        mints + mails a link     MagicLinkRequest
#   POST /l/<token>, unknown email         User.new + save!         LinkClick
#   GET /auth/google_oauth2/callback       User.from_omniauth       GoogleCallback + User.from_omniauth
#   POST /sso_continue, unknown sso_email  User.new + save!         SsoContinue
#
# Two more gates keep the CLOSED doors from saying who is a member:
#
#   POST /login (password form, engine     member 500, stranger 422 PasswordLogin
#     0.90 and below; 0.91 draws none)
#   POST /magic_link, many in a row        no limit                 MagicLinkRequest's rate_limit
#
# Not closed, on purpose: /_studio/local_review find-or-creates its reviewer, but
# the engine draws it outside production only and answers loopback requests only.
#
# The operator adds a member from the console (README, "Accounts").
# test/integration/closed_signup_test.rb drives every door as a stranger and as a
# member. An engine bump that adds a NEW account-creating door is not caught by
# this module: re-read the engine's controllers for `User.new` when bumping.
module ClosedSignup
  MESSAGE = "This is a private family site, so new accounts are closed. " \
            "If you are family, ask to be added."

  # The sign-in email's body (config/initializers/closed_signup.rb). The engine's
  # default promises to create an account for a new address.
  MAGIC_LINK_BODY = "Tap the button below to sign in to {app}. No password needed."

  # How long a magic-link request takes at the least, in seconds. A member's
  # request does more work than a stranger's (two inserts and a job, against one
  # lookup), and the gap is readable from outside: 118 ms against 75 ms at the
  # median over 20 requests each on a development desk, before this floor. Both
  # answers are held to the same floor so the clock says nothing either. Zero in
  # the test environment (config/environments/test.rb).
  DEFAULT_RESPONSE_FLOOR = 0.4

  def self.response_floor
    Rails.configuration.x.closed_signup.response_floor || DEFAULT_RESPONSE_FLOOR
  end

  # POST /magic_link. The engine already answers a malformed address with its
  # ordinary "Check your inbox" response while minting and mailing nothing. A
  # stranger's address is handed to it as exactly that, so the response a
  # stranger sees is the engine's own, not a copy of it that could drift: same
  # status, same redirect, same flash, same JSON. Nothing in it says whether the
  # address belongs to a member, and neither does how long it took.
  module MagicLinkRequest
    # Requests per client address in WINDOW before the next is refused. A family
    # member asks for a link once or twice; this stops a script from spending the
    # mail quota or holding Puma threads on the response floor below.
    LIMIT = 10
    WINDOW = 15.minutes

    # Solid Cache in the primary database (config/cache.yml), in every
    # environment, so the counters are rows every process reads: a second Puma
    # worker or dyno counts against the same LIMIT, and a deploy or the daily
    # dyno restart does not hand every client a fresh one. Its own store, not
    # Rails.cache, which is a null store in test and per-process memory in
    # production. Each increment locks its row, so concurrent requests from
    # one address cannot both read the same count.
    #
    # Solid Cache answers a lost database with nil rather than raising, and
    # Rails' rate_limit lets a nil count through: an outage opens the limit
    # rather than closing sign-in, and the database being down closes sign-in
    # anyway.
    STORE = SolidCache::Store.new

    LIMITED_MESSAGE = "Too many sign-in requests from here. Please wait a few minutes and try again."

    # Refused before the engine's action and before the response floor, and the
    # same refusal whatever address was asked for, so it says nothing about who
    # is a member. Keyed on request.remote_ip, which only the Heroku router can
    # set (config/initializers/forwarded_headers.rb).
    def self.prepended(controller)
      controller.rate_limit to: LIMIT, within: WINDOW, only: :create, store: STORE,
                            name: "closed_signup_magic_link", scope: "closed_signup",
                            with: -> {
                              respond_to do |format|
                                format.json { render json: { error: LIMITED_MESSAGE }, status: :too_many_requests }
                                format.html { redirect_to login_path, alert: LIMITED_MESSAGE }
                              end
                            }
    end

    def create
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      params[:email] = "" unless User.member_email?(params[:email])
      super
    ensure
      remaining = ClosedSignup.response_floor - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
      sleep(remaining) if remaining.positive?
    end
  end

  # POST /login. studio-engine up to 0.90 draws a password sign-in for every
  # app, but this one has no passwords: User has no authenticate, so the
  # engine's action answered a member with a 500 and an ErrorLog and a stranger
  # with a 422, which told the two apart in one request. Nobody here signs in by
  # password, so every request gets the same answer and no address is looked up.
  #
  # From studio-engine 0.91 (PR 420) the engine draws POST /login only for an
  # app with :password in auth_methods, and this app has none, so the route 404s
  # for everyone and this module is never reached. Delete it, and its line in
  # config/initializers/closed_signup.rb, in the commit that bumps the engine to
  # 0.91; test/integration/closed_signup_test.rb holds on either engine.
  module PasswordLogin
    MESSAGE = "This site signs in with an emailed link or Google, not a password."

    def create
      redirect_to login_path, alert: MESSAGE, status: :see_other
    end
  end

  # POST /l/<token> for an address with no account. Reached only by a link that
  # was minted before this gate shipped (links live 15 minutes) or by hand. The
  # token has already burned; no account is made and no session is started.
  module LinkClick
    private

    def sign_up_new(_link)
      redirect_to link_login_path, alert: ClosedSignup::MESSAGE
    end
  end

  # GET /auth/google_oauth2/callback. A Google account that matches no member is
  # refused here with a plain sentence. A member's goes to the engine, which
  # re-validates the id_token before User.from_omniauth signs them in.
  module GoogleCallback
    def create
      return super if User.google_member?(request.env["omniauth.auth"])

      redirect_to login_path, alert: ClosedSignup::MESSAGE
    end
  end

  # POST /sso_continue. Shared-cookie SSO is off for this app
  # (config/initializers/session_store.rb), so no visitor carries an sso_email
  # today. The engine action behind it creates a User for an unknown one, so it
  # is gated anyway rather than left to depend on a cookie setting.
  module SsoContinue
    def sso_continue
      return super unless sso_user_available?
      return super if User.member_email?(session[:sso_email])

      redirect_to login_path, alert: ClosedSignup::MESSAGE
    end
  end
end
