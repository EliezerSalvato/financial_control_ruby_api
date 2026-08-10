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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_143100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "account_kind", ["bank_account", "cash"]
  create_enum "bank_account_type", ["checking", "savings", "investment", "salary"]

  create_table "accounts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.enum "bank_account_type", enum_type: "bank_account_type"
    t.string "color", limit: 9, null: false
    t.datetime "created_at", null: false
    t.decimal "current_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.uuid "institution_id"
    t.enum "kind", null: false, enum_type: "account_kind"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_accounts_on_user_id_and_lower_name", unique: true
    t.index ["institution_id"], name: "index_accounts_on_institution_id"
    t.index ["user_id", "active"], name: "index_accounts_on_user_id_and_active"
    t.index ["user_id"], name: "index_accounts_on_user_id"
    t.check_constraint "kind = 'bank_account'::account_kind AND bank_account_type IS NOT NULL AND institution_id IS NOT NULL OR kind = 'cash'::account_kind AND bank_account_type IS NULL AND institution_id IS NULL", name: "accounts_kind_consistency"
  end

  create_table "categories", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color", limit: 9, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_categories_on_user_id_and_lower_name", unique: true
    t.index ["user_id", "active"], name: "index_categories_on_user_id_and_active"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "credit_cards", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "available_limit", precision: 15, scale: 2, default: "0.0", null: false
    t.integer "closing_day", null: false
    t.datetime "created_at", null: false
    t.uuid "default_payment_account_id", null: false
    t.integer "due_day", null: false
    t.uuid "institution_id", null: false
    t.string "name", null: false
    t.string "network", null: false
    t.decimal "total_limit", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_credit_cards_on_user_id_and_lower_name", unique: true
    t.index ["default_payment_account_id"], name: "index_credit_cards_on_default_payment_account_id"
    t.index ["institution_id"], name: "index_credit_cards_on_institution_id"
    t.index ["user_id", "active"], name: "index_credit_cards_on_user_id_and_active"
    t.index ["user_id"], name: "index_credit_cards_on_user_id"
    t.check_constraint "available_limit >= 0::numeric AND available_limit <= total_limit", name: "credit_cards_available_limit_within_total"
    t.check_constraint "closing_day >= 1 AND closing_day <= 31", name: "credit_cards_closing_day_range"
    t.check_constraint "due_day >= 1 AND due_day <= 31", name: "credit_cards_due_day_range"
    t.check_constraint "total_limit >= 0::numeric", name: "credit_cards_total_limit_non_negative"
  end

  create_table "institutions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "logo_key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_institutions_on_user_id_and_lower_name", unique: true
    t.index ["user_id", "active"], name: "index_institutions_on_user_id_and_active"
    t.index ["user_id"], name: "index_institutions_on_user_id"
  end

  create_table "tags", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color", limit: 9, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_tags_on_user_id_and_lower_name", unique: true
    t.index ["user_id", "active"], name: "index_tags_on_user_id_and_active"
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "user_email_confirmations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "new_email"
    t.string "old_email"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["token_digest"], name: "index_user_email_confirmations_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_email_confirmations_on_user_id"
  end

  create_table "user_password_resets", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "reset_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["token_digest"], name: "index_user_password_resets_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_password_resets_on_user_id"
  end

  create_table "user_sessions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.string "refresh_token_digest", null: false
    t.datetime "refresh_token_expires_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["refresh_token_digest"], name: "index_user_sessions_on_refresh_token_digest", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "versions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.uuid "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object"
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "accounts", "institutions"
  add_foreign_key "accounts", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "credit_cards", "accounts", column: "default_payment_account_id"
  add_foreign_key "credit_cards", "institutions"
  add_foreign_key "credit_cards", "users"
  add_foreign_key "institutions", "users"
  add_foreign_key "tags", "users"
  add_foreign_key "user_email_confirmations", "users"
  add_foreign_key "user_password_resets", "users"
  add_foreign_key "user_sessions", "users"
end
