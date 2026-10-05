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

  # POST /magic_link. The engine already answers a malformed address with its
  # ordinary "Check your inbox" response while minting and mailing nothing. A
  # stranger's address is handed to it as exactly that, so the response a
  # stranger sees is the engine's own, not a copy of it that could drift: same
  # status, same redirect, same flash, same JSON. Nothing in it says whether the
  # address belongs to a member.
  module MagicLinkRequest
    def create
      params[:email] = "" unless User.member_email?(params[:email])
      super
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
