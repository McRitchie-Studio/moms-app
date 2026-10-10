# Renders config/storage.yml the way a given boot would: under a chosen
# Rails.env and a chosen set of storage variables, both restored afterwards.
# storage.yml reads Rails.env and ENV directly, which is why the block has to
# run under the real ones. Tests parallelize by PROCESS, so no sibling sees it.
# The credentials are sentinels; nothing here makes a network call.
module StorageBootHelper
  STORAGE_YML = Rails.root.join("config/storage.yml")
  R2_ENDPOINT = "https://sentinel-account.r2.cloudflarestorage.com".freeze
  R2_ENV = {
    "R2_ENDPOINT" => R2_ENDPOINT,
    "R2_ACCESS_KEY_ID" => "r2-sentinel-id",
    "R2_SECRET_ACCESS_KEY" => "r2-sentinel-secret"
  }.freeze
  # Everything storage.yml reads, cleared, so a developer's shell cannot decide a
  # test. The AWS and S3_BUCKET names are here because nothing may read them now.
  CLEAN_ENV = {
    "ACTIVE_STORAGE_BACKEND" => nil, "QA_ENV" => nil, "SECRET_KEY_BASE_DUMMY" => nil,
    "R2_ENDPOINT" => nil, "R2_ACCESS_KEY_ID" => nil, "R2_SECRET_ACCESS_KEY" => nil,
    "AWS_ACCESS_KEY_ID" => nil, "AWS_SECRET_ACCESS_KEY" => nil, "AWS_REGION" => nil, "S3_BUCKET" => nil
  }.freeze

  def storage_configs(rails_env: "test", env: {})
    with_boot(rails_env, env) { ActiveSupport::ConfigurationFile.parse(STORAGE_YML) }
  end

  def parse_storage(**boot) = storage_configs(**boot).deep_symbolize_keys

  def amazon_service(rails_env:, env:)
    with_boot(rails_env, env) do
      ActiveStorage::Service::Configurator.build(:amazon, ActiveSupport::ConfigurationFile.parse(STORAGE_YML))
    end
  end

  def with_boot(rails_env, vars)
    vars = CLEAN_ENV.merge(vars)
    previous_env = vars.keys.to_h { |k| [ k, ENV[k] ] }
    previous_rails_env = Rails.env.to_s
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    Rails.env = rails_env
    yield
  ensure
    Rails.env = previous_rails_env
    previous_env.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
