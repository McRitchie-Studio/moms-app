require "test_helper"
require "open3"
require_relative "../support/storage_boot_helper"

# [integration] THE BOOT MATRIX, AGAINST REAL PROCESSES. A bad storage config
# passes Heroku's release phase and then crash-loops the app, and a unit test on
# a helper cannot see that: whether a missing variable stops the BOOT depends on
# Rails loading config/storage.yml during it (production eager-loads the blob
# model, which is what parses the file). So each row here starts a fresh
# `bin/rails runner` under the environment a dyno or a laptop would have and
# reads how it ended. No row reaches the network or a database.
class StorageBootTest < ActiveSupport::TestCase
  include StorageBootHelper

  # An address nothing listens on: the boot must not depend on a database, and a
  # developer's own development database must not decide a row (the engine's
  # boot-time schema check skips when it cannot connect).
  NO_DATABASE = { "DATABASE_URL" => "postgres://127.0.0.1:1/never-connected" }.freeze
  PRODUCTION = NO_DATABASE.merge("RAILS_ENV" => "production", "SECRET_KEY_BASE" => "storage-boot-test-only").freeze
  DEVELOPMENT = NO_DATABASE.merge("RAILS_ENV" => "development").freeze
  REPORT = <<~RUBY.squish.freeze
    service = ActiveStorage::Blob.service;
    puts "BOOTED active=" + service.class.name + " bucket=" + (service.respond_to?(:bucket) ? service.bucket.name : "none")
  RUBY

  test "production with no R2 variable fails the boot, naming the first one" do
    output, status = boot(PRODUCTION)
    assert_not status.success?, output
    assert_match(/R2_ENDPOINT must be set in production/, output)
    assert_no_match(/BOOTED/, output)
  end

  # One variable short is as fatal as none. The last one read is the row here;
  # each variable in turn is test/lib/storage_backend_test.rb.
  test "production missing only the secret fails the boot, naming it" do
    output, status = boot(PRODUCTION.merge(R2_ENV).merge("R2_SECRET_ACCESS_KEY" => nil))
    assert_not status.success?, output
    assert_match(/R2_SECRET_ACCESS_KEY must be set in production/, output)
    assert_no_match(/BOOTED/, output)
  end

  test "production with the R2 variables boots on R2 with the backend unset or r2" do
    [ nil, "r2" ].each do |backend|
      output, status = boot(PRODUCTION.merge(R2_ENV).merge("ACTIVE_STORAGE_BACKEND" => backend))
      assert status.success?, "ACTIVE_STORAGE_BACKEND=#{backend.inspect}: #{output}"
      assert_match(/BOOTED active=ActiveStorage::Service::StudioTrashS3Service bucket=moms-app-production/, output)
    end
  end

  test "a QA boot resolves the dev bucket" do
    output, status = boot(PRODUCTION.merge(R2_ENV).merge("QA_ENV" => "true"))
    assert status.success?, output
    assert_match(/BOOTED active=ActiveStorage::Service::StudioTrashS3Service bucket=moms-app-dev/, output)
  end

  test "production with the retired s3 value fails the boot with a clear message" do
    output, status = boot(PRODUCTION.merge(R2_ENV).merge("ACTIVE_STORAGE_BACKEND" => "s3"))
    assert_not status.success?, output
    assert_match(/ACTIVE_STORAGE_BACKEND="s3" is not supported: Active Storage runs on Cloudflare R2 only/, output)
  end

  # The Dockerfile's `SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile`: a
  # production boot that holds no secret on purpose. It must load storage.yml.
  test "a keyless production asset build still loads storage.yml" do
    output, status = boot(PRODUCTION.merge("SECRET_KEY_BASE" => nil, "SECRET_KEY_BASE_DUMMY" => "1"),
                          'puts "CONFIGURED=" + ActiveStorage::Blob.services.send(:configurations).keys.sort.join(",")')
    assert status.success?, output
    assert_match(/CONFIGURED=amazon,local,test/, output)
  end

  test "a keyless development boot loads storage.yml and stores on Disk" do
    output, status = boot(DEVELOPMENT,
                          'puts "CONFIGURED=" + ActiveStorage::Blob.services.send(:configurations).keys.sort.join(","); ' + REPORT)
    assert status.success?, output
    assert_match(/CONFIGURED=amazon,local,test/, output)
    assert_match(/BOOTED active=ActiveStorage::Service::DiskService/, output)
  end

  private

  # A fresh process with every storage variable cleared, then `vars` applied
  # (nil unsets). Returns [combined output, Process::Status].
  def boot(vars, script = REPORT)
    env = CLEAN_ENV.merge("RAILS_ENV" => nil, "RACK_ENV" => nil).merge(vars).transform_values { |v| v&.to_s }
    Open3.capture2e(env, Rails.root.join("bin/rails").to_s, "runner", script, chdir: Rails.root.to_s)
  end
end
