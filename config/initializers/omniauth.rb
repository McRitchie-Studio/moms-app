Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    scope: "email,profile",
    prompt: "select_account"
end

# Keep OmniAuth's request phase POST-only (CSRF-protected). Custom Google
# entrypoints must POST to /auth/google_oauth2, never GET-redirect.
OmniAuth.config.allowed_request_methods = [:post]
