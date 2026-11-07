require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MomsApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # THE FRIENDLY NOT-FOUND PAGE (studio-engine docs/NOT_FOUND_PAGE.md, task
    # apps-adopt-not-found-page). A lost visitor, on an unknown address or a
    # record that is not there, gets the app's name, mark and a button home
    # inside the app's layout, with status 404. JSON keeps Rails' 404 JSON. If
    # the page cannot render, the branded public/404.html answers instead.
    # Guarded so it switches on when the release relocks an engine that has it;
    # public/404.html answers until then.
    # allow_browser :modern (ApplicationController) answers an old browser
    # with a 406, so that browser gets public/404.html: it is plain HTML and
    # CSS with no custom properties, and reads in any browser.
    config.exceptions_app = Studio::ExceptionsApp.new if defined?(Studio::ExceptionsApp)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
