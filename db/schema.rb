# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_08_230855) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.integer "audio_duration_seconds"
    t.string "author"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error_message"
    t.integer "full_duration_seconds"
    t.string "narrator"
    t.string "slug"
    t.string "source", default: "librivox"
    t.string "source_identifier"
    t.string "source_url"
    t.string "status", default: "pending", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_books_on_slug", unique: true
    t.index ["source_identifier"], name: "index_books_on_source_identifier"
  end

  create_table "chapters", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.float "duration_seconds"
    t.boolean "included", default: false, null: false
    t.integer "position", null: false
    t.bigint "size_bytes"
    t.string "source_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["book_id", "position"], name: "index_chapters_on_book_id_and_position", unique: true
    t.index ["book_id"], name: "index_chapters_on_book_id"
  end

  create_table "error_logs", force: :cascade do |t|
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.text "inspect"
    t.text "message"
    t.bigint "parent_id"
    t.string "parent_name"
    t.string "parent_type"
    t.string "slug"
    t.bigint "target_id"
    t.string "target_name"
    t.string "target_type"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_error_logs_on_slug", unique: true
  end

  create_table "studio_email_deliveries", force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "args", default: [], null: false
    t.datetime "created_at", null: false
    t.string "email_key", null: false
    t.text "error"
    t.jsonb "kwargs", default: {}, null: false
    t.string "mailer", null: false
    t.boolean "sent", default: false, null: false
    t.datetime "sent_at"
    t.string "to"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["created_at"], name: "index_studio_email_deliveries_on_created_at"
    t.index ["email_key"], name: "index_studio_email_deliveries_on_email_key"
    t.index ["sent"], name: "index_studio_email_deliveries_on_sent"
    t.index ["user_id"], name: "index_studio_email_deliveries_on_user_id"
  end

  create_table "theme_settings", force: :cascade do |t|
    t.string "accent1"
    t.string "accent2"
    t.string "app_name"
    t.datetime "created_at", null: false
    t.string "danger"
    t.string "dark"
    t.string "light"
    t.string "primary"
    t.datetime "updated_at", null: false
    t.string "warning"
    t.index ["app_name"], name: "index_theme_settings_on_app_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "provider"
    t.string "role", default: "viewer"
    t.string "slug"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chapters", "books"
  add_foreign_key "studio_email_deliveries", "users"
end
