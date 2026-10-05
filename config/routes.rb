Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # Public signup is closed (app/controllers/concerns/closed_signup.rb). Drawn
  # BEFORE the engine's routes so it wins: /signup offers no form and accepts no
  # POST, it sends the visitor to sign-in. `as: nil` leaves the engine's
  # signup_path helper as the only route by that name.
  match "signup", to: redirect("/login"), via: %i[get post], as: nil

  # Studio engine auth + admin routes: login/logout, magic_link, Google callback,
  # error_logs, admin/theme, admin/style, developer desk. It also draws /signup,
  # which the line above shadows.
  Studio.routes(self)

  # Home
  root "pages#index"

  # Audiobook library
  resources :books, only: %i[index show new create]

  # Family photo slideshow (consolidated from karen_mcritchie)
  get "slideshow", to: "slideshow#index"

  # App-specific routes go below.
end
