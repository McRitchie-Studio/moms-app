# frozen_string_literal: true

# ACTIVE STORAGE RUNS ON CLOUDFLARE R2, AND ONLY THERE. AWS was retired on
# 2026-10-10 (IAM users and keys deleted), so there is no S3 store to select and
# no mirror to write: config/storage.yml defines one cloud service and reads
# everything it needs from here.
#
# The service keeps the NAME `amazon` because every blob row records it; only
# what the name resolves to moved, so no blob row was ever rewritten.
#
#   ACTIVE_STORAGE_BACKEND  unset or `r2`. Any other value RAISES at boot: the
#                           retired stages (s3, mirror_to_r2, mirror_to_s3) point
#                           at a store that no longer exists, and a typo must not
#                           read as a successful setting.
#   R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
#                           1Password item r2.moms-app. REQUIRED in production
#                           (QA included: a QA app boots RAILS_ENV=production);
#                           a missing one raises at boot, naming the variable.
#
# Test, CI and a keyless development boot load storage.yml without any of them:
# those environments store on Disk (config/environments/*.rb). There the three
# values render as inert placeholders, so a keyless process that does build the
# `amazon` service gets a client that reaches nothing: it never falls through
# to AWS endpoints or to the SDK's default credential chain.
module StorageBackend
  BACKEND = "r2"
  R2_VARIABLES = %w[R2_ENDPOINT R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY].freeze
  # What a keyless, non-production process renders. `.invalid` is a reserved
  # top-level domain (RFC 2606): it resolves nowhere.
  UNCONFIGURED = {
    "R2_ENDPOINT" => "https://r2-not-configured.invalid",
    "R2_ACCESS_KEY_ID" => "r2-not-configured",
    "R2_SECRET_ACCESS_KEY" => "r2-not-configured"
  }.freeze
  PRODUCTION_BUCKET = "moms-app-production"
  DEV_BUCKET = "moms-app-dev"

  module_function

  # The one backend, after refusing any other value. storage.yml calls it for
  # the refusal; the return value is for a caller that wants to print it.
  def backend!(env = ENV)
    value = env["ACTIVE_STORAGE_BACKEND"].to_s.strip
    return BACKEND if value.empty? || value == BACKEND

    raise ArgumentError,
          "ACTIVE_STORAGE_BACKEND=#{value.inspect} is not supported: Active Storage runs on " \
          "Cloudflare R2 only (AWS S3 was retired 2026-10-10). Unset it or set it to #{BACKEND}."
  end

  # An R2 connection variable. Blank reads as unset. Where it is required a
  # blank RAISES, so a bad config fails the boot instead of the first upload;
  # elsewhere it is the inert placeholder.
  def r2_setting(name, env: ENV, required: r2_required?(env))
    value = env[name].to_s.strip
    return value unless value.empty?
    return UNCONFIGURED.fetch(name) unless required

    raise ArgumentError,
          "#{name} must be set in production: Active Storage runs on Cloudflare R2 " \
          "(1Password item r2.moms-app holds #{R2_VARIABLES.join(', ')})."
  end

  # Production needs the keys. The one exception is Rails' own build-time flag:
  # `SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile` (the Dockerfile) boots
  # production with no secrets on purpose and never touches storage.
  def r2_required?(env = ENV, rails_env: Rails.env)
    rails_env.to_s == "production" && env["SECRET_KEY_BASE_DUMMY"].to_s.strip.empty?
  end

  # WHICH BUCKET THIS PROCESS OWNS. Only real production gets the production
  # bucket. A QA app boots RAILS_ENV=production, so QA is asked first and wins:
  # without that a QA app would read, write and DELETE production's objects
  # (measured in Carl's storage audit, 2026-09-30). Every other environment
  # resolves the dev bucket, the same answer Studio::S3 gives, so the engine's
  # guard (Studio::S3.guard_production_bucket!) never has a non-production
  # process to refuse.
  def bucket(qa: Studio.qa_environment?, rails_env: Rails.env)
    return DEV_BUCKET if qa

    rails_env.to_s == "production" ? PRODUCTION_BUCKET : DEV_BUCKET
  end
end
