require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Uploaded files — book covers + stitched audiobook audio — live in S3
  # (Heroku dynos have an ephemeral filesystem). See config/storage.yml.
  config.active_storage.service = :amazon

  # Heroku terminates TLS at the router and forwards over http with
  # X-Forwarded-Proto; trust that and force HTTPS everywhere but /up.
  config.assume_ssl = true
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # Single Heroku Postgres: keep the cache in-process and run jobs in-process,
  # so there are no separate solid_* databases to provision.
  config.cache_store = :memory_store
  config.active_job.queue_adapter = :async

  # Links generated in mailer templates (magic-link sign-in emails).
  config.action_mailer.default_url_options = { host: "karenmcritchie.com", protocol: "https" }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS-rebinding / Host-header protection: allow the custom domain + the dyno URL.
  config.hosts = [
    "karenmcritchie.com",
    "www.karenmcritchie.com",
    ENV.fetch("DYNO_HOST", "obscure-plains-6405.herokuapp.com")
  ]
  # /up is the health-check Heroku's load balancer polls (internal addressing).
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
