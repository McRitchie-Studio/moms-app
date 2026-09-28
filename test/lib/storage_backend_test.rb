require "test_helper"

# [unit] The switch that moves moms-app's Active Storage off AWS S3 onto
# Cloudflare R2 (config/initializers/00_storage_backend.rb), asserted on the
# service OBJECTS Active Storage builds from config/storage.yml, not on the YAML
# text: a stage that renders but resolves to the wrong store, or a mirror pointed
# the wrong way, fails here instead of on the first upload after a flip. No test
# makes a network call; the credentials are sentinels.
class StorageBackendTest < ActiveSupport::TestCase
  R2_ENDPOINT = "https://sentinel-account.r2.cloudflarestorage.com".freeze
  R2_ENV = {
    "R2_ENDPOINT" => R2_ENDPOINT,
    "R2_ACCESS_KEY_ID" => "r2-sentinel-id",
    "R2_SECRET_ACCESS_KEY" => "r2-sentinel-secret",
    "AWS_ACCESS_KEY_ID" => "AKIAEXAMPLEONLYTEST",
    "AWS_SECRET_ACCESS_KEY" => "aws-sentinel-secret",
    "S3_BUCKET" => nil,
    "AWS_REGION" => nil
  }.freeze

  test "unset and blank read as the S3 stage" do
    assert_equal "s3", StorageBackend.active_storage_stage({})
    assert_equal "s3", StorageBackend.active_storage_stage({ "ACTIVE_STORAGE_BACKEND" => " " })
  end

  test "an unknown stage raises instead of falling back to S3" do
    assert_raises(ArgumentError) { StorageBackend.active_storage_stage({ "ACTIVE_STORAGE_BACKEND" => "R2" }) }
  end

  def amazon_service(stage)
    with_env(R2_ENV.merge("ACTIVE_STORAGE_BACKEND" => stage)) do
      configs = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage.yml"))
      ActiveStorage::Service::Configurator.build(:amazon, configs)
    end
  end

  def endpoint_of(service) = service.client.client.config.endpoint.to_s

  test "s3 stage: amazon is the AWS service on moms-app-production, unchanged" do
    service = amazon_service("s3")
    assert_instance_of ActiveStorage::Service::S3Service, service
    assert_match(/amazonaws\.com/, endpoint_of(service))
    assert_equal "moms-app-production", service.bucket.name
  end

  test "mirror_to_r2: S3 is primary and R2 receives every write" do
    service = amazon_service("mirror_to_r2")
    assert_instance_of ActiveStorage::Service::MirrorService, service
    assert_match(/amazonaws\.com/, endpoint_of(service.primary))
    assert_equal [ R2_ENDPOINT ], service.mirrors.map { |m| endpoint_of(m) }
  end

  test "mirror_to_s3: R2 is primary and S3 still receives every write" do
    service = amazon_service("mirror_to_s3")
    assert_equal R2_ENDPOINT, endpoint_of(service.primary)
    assert_match(/amazonaws\.com/, endpoint_of(service.mirrors.first))
  end

  test "r2 stage: amazon is R2 alone, same bucket name, R2 keys" do
    service = amazon_service("r2")
    assert_equal R2_ENDPOINT, endpoint_of(service)
    assert_equal "moms-app-production", service.bucket.name
    assert_equal "r2-sentinel-id", service.client.client.config.credentials.access_key_id
  end

  # Active Storage sends Content-MD5 and aws-sdk-s3 >= 1.178 adds a CRC32 by
  # default; R2 refuses a request carrying both (measured 2026-09-28).
  test "every R2 service computes checksums only when required" do
    [ amazon_service("r2"), amazon_service("mirror_to_r2").mirrors.first, amazon_service("mirror_to_s3").primary ].each do |svc|
      assert_equal "when_required", svc.client.client.config.request_checksum_calculation
    end
  end

  test "a non-S3 stage without R2 credentials fails at parse, not at first upload" do
    with_env(R2_ENV.merge("ACTIVE_STORAGE_BACKEND" => "mirror_to_r2", "R2_ENDPOINT" => nil)) do
      assert_raises(ArgumentError) { ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/storage.yml")) }
    end
  end

  private

  def with_env(vars)
    previous = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
