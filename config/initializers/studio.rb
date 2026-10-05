Studio.configure do |config|
  config.app_name = "Moms App"
  config.session_key = :moms_app_user_id
  config.welcome_message = ->(user) { "Welcome to Moms App, #{user.display_name}!" }

  # Passwordless: magic-link email + Google OAuth. No password, no wallet.
  #
  # These are SIGN-IN methods only. Public signup is closed: the engine has no
  # setting for that, so app/controllers/concerns/closed_signup.rb gates every
  # engine flow that would create an account (README, "Accounts").
  config.auth_methods = %i[magic_link google]
  config.registration_params = [ :name, :email ]
  # No magic_link_token_name: it keyed the MessageVerifier purpose for the
  # :signed store, which studio-engine 0.31 retired. Magic links are
  # Studio::Link rows served at the short /l/<token>, and the store is no longer
  # configurable — do NOT add config.magic_link_store, which now raises.

  config.mailer_from = Studio.mailer_from_for_transport(
    ses_from: "Moms App <team@mcritchie.studio>"
  )

  # New SSO users start as viewers. Unreached today: shared-cookie SSO is off
  # (session_store.rb) and ClosedSignup refuses an SSO visitor with no account.
  config.configure_sso_user = ->(user) { user.role = "viewer" }

  config.theme_logos = [
    { file: "favicon.png", title: "Favicon" },
    { file: "logo.png",    title: "Navbar Logo" },
    { file: "logo.png",    title: "Auth Logo" }
  ]

  # Warm pink brand.
  config.theme_primary = "#E86AA6"

  # ---- Site footer (studio-engine >= 0.84, docs/SITE_FOOTER.md) ----
  # The engine's footer, rendered by `studio_site_footer` at the end of the
  # application layout. Every app carries it, family sites included.
  #
  # A family site, so the footer says only what the site already says in public:
  # NO address, NO map, NO phone, NO scheduler, by the operator's instruction
  # (2026-10-03). Without `address:` the engine renders no Location band and
  # never requests Leaflet or a map tile.
  #
  # No `email:` and no `social:` either: the site shows no contact address and no
  # profile handle anywhere today. No `legal:` line: the site publishes no terms
  # or privacy pages (that decision is the operator's, not the footer's).
  # The operator's decision (2026-10-05): close public signup rather than
  # publish them (app/controllers/concerns/closed_signup.rb).
  #
  # The logo is the engine default, the navbar's logo.png (a 64px mark).
  # test/integration/site_footer_test.rb pins the links and the absences.
  config.site_footer = ->(view) {
    {
      name: "Moms App",
      wordmark: %w[Moms App],
      home_path: view.root_path,
      tagline: "Mom's photos and a little library of public-domain audiobooks.",
      # The navbar's links, plus Home. One column: the site has three pages.
      columns: [
        [ "Explore", [ [ "Home", view.root_path ],
                       [ "Photos", view.slideshow_path ],
                       [ "Library", view.books_path ] ] ]
      ]
    }
  }

  # A visitor sees the footer on every page (the engine default). A signed-in
  # admin sees it on the public pages too, and not on the engine's working
  # surfaces (error logs, theme, admin), which stay full height.
  config.site_footer_controllers = %w[pages books slideshow]
end
