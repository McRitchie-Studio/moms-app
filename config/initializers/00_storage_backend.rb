# frozen_string_literal: true

# THE MOVE OFF AWS S3 ONTO CLOUDFLARE R2 (asset-library Wave 2; the recipe is
# mcritchie-studio's docs/agents/system/asset-library-plan.md). moms-app stores
# files through Active Storage only, so one switch moves it, read by
# config/storage.yml, inert until set:
#
#   ACTIVE_STORAGE_BACKEND  s3 (default) → mirror_to_r2 → mirror_to_s3 → r2
#
# The `amazon` service every blob row names keeps its NAME through all four
# stages; only what it resolves to changes, so no blob row is ever rewritten. The
# two mirror stages write both stores, which is what makes the move reversible by
# config. R2 connection details come from R2_ENDPOINT, R2_ACCESS_KEY_ID and
# R2_SECRET_ACCESS_KEY (1Password item r2.moms-app); the bucket name is the same
# on both stores.
#
# An unknown value RAISES at boot rather than falling back to S3: a typo would
# otherwise look like a successful flip while every write kept landing on S3.
module StorageBackend
  ACTIVE_STORAGE_STAGES = %w[s3 mirror_to_r2 mirror_to_s3 r2].freeze

  module_function

  def active_storage_stage(env = ENV)
    value = env["ACTIVE_STORAGE_BACKEND"].to_s.strip
    return ACTIVE_STORAGE_STAGES.first if value.empty?
    return value if ACTIVE_STORAGE_STAGES.include?(value)

    raise ArgumentError, "ACTIVE_STORAGE_BACKEND=#{value.inspect} is not one of #{ACTIVE_STORAGE_STAGES.join(', ')}"
  end

  def require!(env, name)
    value = env[name].to_s.strip
    raise ArgumentError, "#{name} must be set when ACTIVE_STORAGE_BACKEND is not s3" if value.empty?

    value
  end
end
