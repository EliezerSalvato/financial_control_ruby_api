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

ActiveRecord::Schema[8.1].define(version: 2026_08_11_160500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "account_kind", ["bank_account", "cash"]
  create_enum "bank_account_type", ["checking", "savings", "investment", "salary"]
  create_enum "transaction_kind", ["income", "expense", "transfer_between_accounts"]
  create_enum "transaction_limit_consumption_type", ["upfront", "monthly"]
  create_enum "transaction_payment_method", ["pix", "debit", "credit_card", "ted", "doc", "deposit", "cash", "boleto"]
  create_enum "transaction_recurrence_type", ["one_time", "installment", "recurring"]
  create_enum "transaction_status", ["pending", "active", "completed", "canceled"]

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

  create_table "transaction_for_accounts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_transaction_for_accounts_on_account_id"
    t.index ["transaction_id"], name: "index_transaction_for_accounts_on_transaction_id", unique: true
  end

  create_table "transaction_for_credit_cards", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "credit_card_id", null: false
    t.enum "limit_consumption_type", enum_type: "transaction_limit_consumption_type"
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_card_id"], name: "index_transaction_for_credit_cards_on_credit_card_id"
    t.index ["transaction_id"], name: "index_transaction_for_credit_cards_on_transaction_id", unique: true
  end

  create_table "transaction_for_transfer_between_accounts", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "destination_account_id", null: false
    t.uuid "source_account_id", null: false
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_account_id"], name: "idx_on_destination_account_id_311c4ea7c5"
    t.index ["source_account_id"], name: "idx_on_source_account_id_be1ca23848"
    t.index ["transaction_id"], name: "idx_on_transaction_id_ef58530096", unique: true
    t.check_constraint "source_account_id <> destination_account_id", name: "transaction_for_transfer_between_accounts_distinct_accounts"
  end

  create_table "transaction_recurrences", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.virtual "month", type: :integer, null: false, as: "(EXTRACT(month FROM starts_on))::integer", stored: true
    t.date "starts_on", null: false
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 15, scale: 2, null: false
    t.virtual "year", type: :integer, null: false, as: "(EXTRACT(year FROM starts_on))::integer", stored: true
    t.index ["transaction_id", "month", "year"], name: "idx_on_transaction_id_month_year_9d19fc02b4", unique: true
    t.check_constraint "value >= 0::numeric", name: "transaction_recurrences_value_non_negative"
  end

  create_table "transaction_tags", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "tag_id", null: false
    t.uuid "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_on_transaction_id_and_tag_id", unique: true
  end

  create_table "transactions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "category_id", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.date "ends_on"
    t.integer "installments_count"
    t.enum "kind", null: false, enum_type: "transaction_kind"
    t.enum "payment_method", enum_type: "transaction_payment_method"
    t.enum "recurrence_type", null: false, enum_type: "transaction_recurrence_type"
    t.enum "status", default: "pending", null: false, enum_type: "transaction_status"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["description"], name: "index_transactions_on_description"
    t.index ["kind"], name: "index_transactions_on_kind"
    t.index ["payment_method"], name: "index_transactions_on_payment_method"
    t.index ["recurrence_type"], name: "index_transactions_on_recurrence_type"
    t.index ["status"], name: "index_transactions_on_status"
    t.index ["user_id"], name: "index_transactions_on_user_id"
    t.check_constraint "recurrence_type = 'one_time'::transaction_recurrence_type AND installments_count IS NULL AND ends_on IS NULL OR recurrence_type = 'installment'::transaction_recurrence_type AND installments_count > 1 AND ends_on IS NOT NULL OR recurrence_type = 'recurring'::transaction_recurrence_type AND installments_count IS NULL", name: "transactions_recurrence_type_consistency"
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
  add_foreign_key "transaction_for_accounts", "accounts"
  add_foreign_key "transaction_for_accounts", "transactions"
  add_foreign_key "transaction_for_credit_cards", "credit_cards"
  add_foreign_key "transaction_for_credit_cards", "transactions"
  add_foreign_key "transaction_for_transfer_between_accounts", "accounts", column: "destination_account_id"
  add_foreign_key "transaction_for_transfer_between_accounts", "accounts", column: "source_account_id"
  add_foreign_key "transaction_for_transfer_between_accounts", "transactions"
  add_foreign_key "transaction_recurrences", "transactions"
  add_foreign_key "transaction_tags", "tags"
  add_foreign_key "transaction_tags", "transactions"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "users"
  add_foreign_key "user_email_confirmations", "users"
  add_foreign_key "user_password_resets", "users"
  add_foreign_key "user_sessions", "users"
end
