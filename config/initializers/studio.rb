Studio.configure do |config|
  config.app_name = "Moms App"
  config.session_key = :moms_app_user_id
  config.welcome_message = ->(user) { "Welcome to Moms App, #{user.display_name}!" }

  # Passwordless: magic-link email + Google OAuth. No password, no wallet.
  config.auth_methods = %i[magic_link google]
  config.registration_params = [ :name, :email ]
  config.magic_link_token_name = "magic_link_moms_app_v1"

  config.mailer_from = Studio.mailer_from_for_transport(
    ses_from: "Moms App <team@mcritchie.studio>"
  )

  # New SSO users start as viewers.
  config.configure_sso_user = ->(user) { user.role = "viewer" }

  config.theme_logos = [
    { file: "favicon.png", title: "Favicon" },
    { file: "logo.png",    title: "Navbar Logo" },
    { file: "logo.png",    title: "Auth Logo" }
  ]

  # Warm pink brand.
  config.theme_primary = "#E86AA6"
end
