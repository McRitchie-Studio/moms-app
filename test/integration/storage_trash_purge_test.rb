require "test_helper"
require "aws-sdk-s3"
require_relative "../support/storage_boot_helper"

# [integration] A purged attachment is recoverable for three days. R2 has no
# object versioning, so the `amazon` service is the engine's StudioTrashS3
# (config/storage.yml): Blob#purge must COPY the object under trash/ and only
# then delete it. This drives the real path, config/storage.yml -> Active
# Storage's registry -> Blob#purge -> the aws-sdk-s3 client, with the client's
# responses stubbed (Aws stub_responses), so the requests are the SDK's own and
# none of them leaves the process.
class StorageTrashPurgeTest < ActiveSupport::TestCase
  include StorageBootHelper

  KEY = "purge-me-key".freeze

  setup do
    @previous_services = ActiveStorage::Blob.services
    @previous_aws_s3 = Aws.config[:s3]
    Aws.config[:s3] = { stub_responses: true }
  end

  teardown do
    Aws.config[:s3] = @previous_aws_s3
    Aws.config.delete(:s3) if @previous_aws_s3.nil?
    ActiveStorage::Blob.services = @previous_services
  end

  test "purging a blob copies the object to trash before deleting it" do
    service = register_amazon(rails_env: "test")
    client = service.client.client
    client.stub_responses(:head_object, content_length: 42, content_type: "image/png",
                                        etag: %("#{'ab' * 16}"), metadata: {})
    blob = amazon_blob
    assert_same service, blob.service, "a blob row naming amazon resolves the trash service"

    travel_to Time.utc(2026, 10, 10, 12, 0, 0) do
      blob.purge
    end

    assert_not ActiveStorage::Blob.exists?(blob.id), "the blob row is destroyed"
    requests = client.api_requests
    operations = requests.map { |r| r[:operation_name] }
    copy_at = operations.index(:copy_object)
    delete_at = operations.index(:delete_object)
    assert copy_at, "a purge must copy the object to trash; saw #{operations.inspect}"
    assert delete_at, "a purge must still delete the original; saw #{operations.inspect}"
    assert_operator copy_at, :<, delete_at, "copy-to-trash must come BEFORE the delete; saw #{operations.inspect}"
    assert_equal 1, operations.count(:copy_object)
    assert_equal 1, operations.count(:delete_object)

    copy = requests[copy_at][:params]
    epoch_ms = Time.utc(2026, 10, 10, 12, 0, 0).to_i * 1000
    assert_equal "moms-app-dev", copy[:bucket]
    assert_equal "moms-app-dev/#{KEY}", copy[:copy_source]
    assert_equal "trash/2026-10-10/#{epoch_ms}/#{KEY}", copy[:key]
    assert_equal KEY, copy[:metadata]["original-key"]
    assert_equal "test", copy[:metadata]["deleted-env"]

    assert_equal({ bucket: "moms-app-dev", key: KEY }, requests[delete_at][:params])
  end

  # THE ORDER IS THE SAFETY: a copy that fails must leave the original alone.
  test "a failed copy to trash raises and never sends the delete" do
    service = register_amazon(rails_env: "test")
    client = service.client.client
    client.stub_responses(:head_object, content_length: 42, metadata: {})
    client.stub_responses(:copy_object, "InternalError")

    assert_raises(Aws::S3::Errors::InternalError) { service.delete(KEY) }
    assert_not_includes client.api_requests.map { |r| r[:operation_name] }, :delete_object
  end

  test "an object that is already gone is neither copied nor deleted" do
    service = register_amazon(rails_env: "test")
    client = service.client.client
    client.stub_responses(:head_object, "NotFound")

    assert_nil service.delete(KEY)
    assert_equal [ :head_object ], client.api_requests.map { |r| r[:operation_name] }
  end

  # The engine's guard (Studio::S3.guard_production_bucket!). StorageBackend.bucket
  # never hands a non-production process the production bucket, so this is the
  # backstop behind it: a service built for production, used from this test
  # process, refuses both deletes and sends nothing.
  test "a non-production process is refused a delete on the production bucket" do
    service = register_amazon(rails_env: "production")
    client = service.client.client
    assert_equal "moms-app-production", service.bucket.name

    assert_raises(Studio::S3::Trash::ProductionBucketRefused) { service.delete(KEY) }
    assert_raises(Studio::S3::Trash::ProductionBucketRefused) { service.delete_prefixed("variants/#{KEY}/") }
    assert_empty client.api_requests
  end

  # A QA app boots RAILS_ENV=production and resolves the dev bucket, so its own
  # purges pass the guard and are trashed like production's.
  test "a QA process trashes on the dev bucket and records the qa environment" do
    service = register_amazon(rails_env: "production", env: { "QA_ENV" => "true" })
    client = service.client.client
    client.stub_responses(:head_object, content_length: 42, metadata: {})

    with_boot("production", R2_ENV.merge("QA_ENV" => "true")) { service.delete(KEY) }

    copy = client.api_requests.find { |r| r[:operation_name] == :copy_object }
    assert_equal "moms-app-dev", copy[:params][:bucket]
    assert_equal "qa", copy[:params][:metadata]["deleted-env"]
  end

  private

  # Rebuilds Active Storage's registry from config/storage.yml as the given boot
  # would and returns its `amazon` service, the one a blob row naming `amazon`
  # resolves. Its S3 client (service.client.client) answers from stubs.
  def register_amazon(rails_env:, env: {})
    configs = storage_configs(rails_env: rails_env, env: R2_ENV.merge(env))
    ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new(configs)
    service = ActiveStorage::Blob.services.fetch(:amazon)
    assert_instance_of ActiveStorage::Service::StudioTrashS3Service, service
    service
  end

  def amazon_blob
    ActiveStorage::Blob.create!(key: KEY, filename: "cover.png", content_type: "image/png",
                                byte_size: 42, checksum: "sentinel", service_name: "amazon")
  end
end
