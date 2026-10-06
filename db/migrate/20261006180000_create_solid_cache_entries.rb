# The table behind ClosedSignup::MagicLinkRequest's rate-limit counters
# (app/controllers/concerns/closed_signup.rb). It lives in the primary database:
# production has one Heroku Postgres and config/cache.yml names no `database:`,
# so every web process and every deploy reads the same counters. The columns are
# the ones `bin/rails solid_cache:install` (solid_cache 1.0.10) writes to
# db/cache_schema.rb.
class CreateSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false
      t.index [ :byte_size ], name: "index_solid_cache_entries_on_byte_size"
      t.index [ :key_hash, :byte_size ], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index [ :key_hash ], name: "index_solid_cache_entries_on_key_hash", unique: true
    end
  end
end
