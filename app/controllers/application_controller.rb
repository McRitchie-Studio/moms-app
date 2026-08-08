class ApplicationController < ActionController::Base
  # Studio engine: passwordless auth (current_user / logged_in?), theme, and
  # rescue_and_log / ErrorLog error handling.
  include Studio::ErrorHandling

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
