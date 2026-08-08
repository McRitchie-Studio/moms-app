Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  # Studio engine auth + admin routes: login/logout, signup, magic_link,
  # Google callback, error_logs, admin/theme, admin/style, developer desk.
  Studio.routes(self)

  # Home
  root "pages#index"

  # Audiobook library
  resources :books, only: %i[index show new create]

  # Family photo slideshow (consolidated from karen_mcritchie)
  get "slideshow", to: "slideshow#index"

  # App-specific routes go below.
end
