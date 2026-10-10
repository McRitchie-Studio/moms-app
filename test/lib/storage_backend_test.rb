require "test_helper"
require_relative "../support/storage_boot_helper"

# [unit] Active Storage runs on Cloudflare R2 only
# (config/initializers/00_storage_backend.rb, config/storage.yml). A bad storage
# config passes Heroku's release phase and then crash-loops the app, so this
# pins the BOOT MATRIX: which values load, which raise, and what each resolves
# to, asserted on the rendered config and on the service OBJECT Active Storage
# builds from it. The same matrix against real processes is
# test/integration/storage_boot_test.rb. No test makes a network call; the
# credentials are sentinels.
class StorageBackendTest < ActiveSupport::TestCase
  include StorageBootHelper

  # --- the backend switch ---------------------------------------------------

  test "unset and blank mean R2, never S3" do
    assert_equal "r2", StorageBackend.backend!({})
    assert_equal "r2", StorageBackend.backend!({ "ACTIVE_STORAGE_BACKEND" => " " })
  end

  test "r2 is still accepted, because production sets it" do
    assert_equal "r2", StorageBackend.backend!({ "ACTIVE_STORAGE_BACKEND" => "r2" })
  end

  test "every retired stage raises a message naming the value and the fix" do
    %w[s3 mirror_to_r2 mirror_to_s3].each do |retired|
      error = assert_raises(ArgumentError) { StorageBackend.backend!({ "ACTIVE_STORAGE_BACKEND" => retired }) }
      assert_includes error.message, %(ACTIVE_STORAGE_BACKEND="#{retired}")
      assert_match(/Cloudflare R2 only/, error.message)
      assert_match(/Unset it or set it to r2/, error.message)
    end
  end

  test "a typo raises instead of reading as R2" do
    assert_raises(ArgumentError) { StorageBackend.backend!({ "ACTIVE_STORAGE_BACKEND" => "R2" }) }
  end

  # --- the R2 variables -----------------------------------------------------

  test "R2 variables are required in production and nowhere else" do
    assert StorageBackend.r2_required?({}, rails_env: "production")
    assert_not StorageBackend.r2_required?({}, rails_env: "development")
    assert_not StorageBackend.r2_required?({}, rails_env: "test")
  end

  test "the Dockerfile's keyless asset build is the one production exemption" do
    assert_not StorageBackend.r2_required?({ "SECRET_KEY_BASE_DUMMY" => "1" }, rails_env: "production")
    assert StorageBackend.r2_required?({ "SECRET_KEY_BASE_DUMMY" => " " }, rails_env: "production")
  end

  test "a required variable that is missing or blank raises naming it" do
    StorageBackend::R2_VARIABLES.each do |name|
      [ {}, { name => "  " } ].each do |env|
        error = assert_raises(ArgumentError) { StorageBackend.r2_setting(name, env: env, required: true) }
        assert_match(/\A#{name} must be set in production/, error.message)
      end
    end
  end

  test "a variable that is set reads its value, stripped" do
    assert_equal "v", StorageBackend.r2_setting("R2_ENDPOINT", env: { "R2_ENDPOINT" => " v " }, required: true)
    assert_equal "v", StorageBackend.r2_setting("R2_ENDPOINT", env: { "R2_ENDPOINT" => "v" }, required: false)
  end

  test "a missing variable that is not required reads an inert placeholder" do
    StorageBackend::R2_VARIABLES.each do |name|
      assert_match(/not-configured/, StorageBackend.r2_setting(name, env: {}, required: false))
    end
    assert_equal "r2-not-configured.invalid", URI(StorageBackend::UNCONFIGURED.fetch("R2_ENDPOINT")).host
  end

  # --- the bucket -----------------------------------------------------------

  test "only real production owns the production bucket; QA wins over it" do
    assert_equal "moms-app-production", StorageBackend.bucket(qa: false, rails_env: "production")
    assert_equal "moms-app-dev", StorageBackend.bucket(qa: true, rails_env: "production")
    assert_equal "moms-app-dev", StorageBackend.bucket(qa: false, rails_env: "development")
    assert_equal "moms-app-dev", StorageBackend.bucket(qa: false, rails_env: "test")
  end

  # --- config/storage.yml, rendered -----------------------------------------

  test "storage.yml defines Disk for test and local and exactly one cloud service" do
    configs = parse_storage
    assert_equal %w[amazon local test], configs.keys.map(&:to_s).sort
    assert_equal "StudioTrashS3", configs[:amazon][:service]
    assert_equal "auto", configs[:amazon][:region]
  end

  test "test and keyless development load storage.yml with no R2 variable" do
    %w[test development].each do |rails_env|
      configs = parse_storage(rails_env: rails_env)
      assert_equal "https://r2-not-configured.invalid", configs[:amazon][:endpoint], rails_env
      assert_equal "moms-app-dev", configs[:amazon][:bucket], rails_env
    end
  end

  # Keyless must never mean "AWS, with whatever key the SDK's default chain
  # finds": the client a keyless process builds is pinned to the placeholder
  # endpoint and to static placeholder credentials.
  test "a keyless amazon service points at nothing, never at AWS" do
    config = amazon_service(rails_env: "development", env: {}).client.client.config
    assert_equal "https://r2-not-configured.invalid", config.endpoint.to_s
    assert_instance_of Aws::Credentials, config.credentials
    assert_equal "r2-not-configured", config.credentials.access_key_id
  end

  test "production without an R2 variable raises at parse, naming the variable" do
    StorageBackend::R2_VARIABLES.each do |name|
      error = assert_raises(ArgumentError) { parse_storage(rails_env: "production", env: R2_ENV.merge(name => nil)) }
      assert_match(/\A#{name} must be set in production/, error.message)
    end
  end

  test "production with no storage variable at all raises, it does not fall back to S3" do
    error = assert_raises(ArgumentError) { parse_storage(rails_env: "production") }
    assert_match(/\AR2_ENDPOINT must be set/, error.message)
  end

  test "production with the R2 variables resolves R2 whether the backend is unset or r2" do
    [ nil, "r2" ].each do |backend|
      service = amazon_service(rails_env: "production", env: R2_ENV.merge("ACTIVE_STORAGE_BACKEND" => backend))
      assert_instance_of ActiveStorage::Service::StudioTrashS3Service, service
      assert_equal R2_ENDPOINT, service.client.client.config.endpoint.to_s
      assert_equal "r2-sentinel-id", service.client.client.config.credentials.access_key_id
      assert_equal "moms-app-production", service.bucket.name
    end
  end

  test "a retired backend value fails the parse in every environment" do
    %w[production development test].each do |rails_env|
      assert_raises(ArgumentError, rails_env) do
        parse_storage(rails_env: rails_env, env: R2_ENV.merge("ACTIVE_STORAGE_BACKEND" => "s3"))
      end
    end
  end

  # A QA app boots RAILS_ENV=production; QA_ENV is what keeps it off production.
  test "QA_ENV resolves moms-app-dev on a production boot" do
    configs = parse_storage(rails_env: "production", env: R2_ENV.merge("QA_ENV" => "true"))
    assert_equal "moms-app-dev", configs[:amazon][:bucket]
  end

  # The override this file used to honour is gone: nothing can point a process
  # at a bucket its environment does not own.
  test "S3_BUCKET and the AWS variables are no longer read" do
    stale = { "S3_BUCKET" => "some-other-bucket", "AWS_ACCESS_KEY_ID" => "AKIAEXAMPLEONLYTEST",
              "AWS_SECRET_ACCESS_KEY" => "aws-sentinel-secret", "AWS_REGION" => "us-east-2" }
    service = amazon_service(rails_env: "production", env: R2_ENV.merge(stale))
    assert_equal "moms-app-production", service.bucket.name
    assert_equal "r2-sentinel-id", service.client.client.config.credentials.access_key_id
    assert_equal "auto", service.client.client.config.region

    qa = parse_storage(rails_env: "production", env: R2_ENV.merge(stale).merge("QA_ENV" => "true"))
    assert_equal "moms-app-dev", qa[:amazon][:bucket]
  end

  # Active Storage sends Content-MD5 and aws-sdk-s3 >= 1.178 adds a CRC32 by
  # default; R2 refuses a request carrying both (measured 2026-09-28).
  test "the R2 service computes and validates checksums only when required" do
    config = amazon_service(rails_env: "production", env: R2_ENV).client.client.config
    assert_equal "when_required", config.request_checksum_calculation
    assert_equal "when_required", config.response_checksum_validation
  end

  test "production stores on the amazon service; development and test on Disk" do
    assert_match(/config\.active_storage\.service = :amazon$/, Rails.root.join("config/environments/production.rb").read)
    assert_match(/config\.active_storage\.service = :local$/, Rails.root.join("config/environments/development.rb").read)
    assert_equal :test, Rails.configuration.active_storage.service
  end
end
