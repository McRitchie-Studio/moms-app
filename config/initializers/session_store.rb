# App-specific cookie key. Shared-domain SSO stays off until the hub/satellite
# cookie contract is deliberately reviewed.
Rails.application.config.session_store :cookie_store,
  key: "_moms_app_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
