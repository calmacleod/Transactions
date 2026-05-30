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

ActiveRecord::Schema[8.1].define(version: 2026_05_30_140622) do
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

  create_table "ai_chat_messages", force: :cascade do |t|
    t.integer "ai_chat_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "estimated_cost_microdollars", default: 0, null: false
    t.integer "input_tokens"
    t.json "metadata", default: {}, null: false
    t.string "model"
    t.integer "output_tokens"
    t.string "role", null: false
    t.string "status", default: "complete", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["ai_chat_id", "created_at"], name: "index_ai_chat_messages_on_ai_chat_id_and_created_at"
    t.index ["ai_chat_id"], name: "index_ai_chat_messages_on_ai_chat_id"
    t.index ["status"], name: "index_ai_chat_messages_on_status"
    t.index ["user_id"], name: "index_ai_chat_messages_on_user_id"
  end

  create_table "ai_chat_transactions", force: :cascade do |t|
    t.integer "ai_chat_id", null: false
    t.datetime "created_at", null: false
    t.integer "expense_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["ai_chat_id", "expense_transaction_id"], name: "index_ai_chat_transactions_uniqueness", unique: true
    t.index ["ai_chat_id"], name: "index_ai_chat_transactions_on_ai_chat_id"
    t.index ["expense_transaction_id"], name: "index_ai_chat_transactions_on_expense_transaction_id"
    t.index ["user_id"], name: "index_ai_chat_transactions_on_user_id"
  end

  create_table "ai_chats", force: :cascade do |t|
    t.json "context_filters", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "model"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_ai_chats_on_created_at"
    t.index ["user_id"], name: "index_ai_chats_on_user_id"
  end

  create_table "ai_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "estimated_cost_cents", default: 0, null: false
    t.integer "estimated_cost_microdollars", default: 0, null: false
    t.string "feature", null: false
    t.integer "input_tokens"
    t.string "model"
    t.integer "output_tokens"
    t.boolean "successful", default: true, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["created_at"], name: "index_ai_requests_on_created_at"
    t.index ["feature"], name: "index_ai_requests_on_feature"
    t.index ["user_id"], name: "index_ai_requests_on_user_id"
  end

  create_table "ai_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_ai_settings_on_key", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "monthly_budget_cents"
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id", "name"], name: "index_categories_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "classification_runs", force: :cascade do |t|
    t.string "active_job_id"
    t.integer "ai_count", default: 0, null: false
    t.datetime "cancel_requested_at"
    t.integer "classified_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.integer "failed_count", default: 0, null: false
    t.datetime "finished_at"
    t.text "notes"
    t.integer "processed_count", default: 0, null: false
    t.integer "rule_based_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["created_at"], name: "index_classification_runs_on_created_at"
    t.index ["status"], name: "index_classification_runs_on_status"
    t.index ["user_id"], name: "index_classification_runs_on_user_id"
  end

  create_table "expense_transaction_subcategories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expense_transaction_id", null: false
    t.integer "transaction_subcategory_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["expense_transaction_id", "transaction_subcategory_id"], name: "index_expense_transaction_subcategories_uniqueness", unique: true
    t.index ["expense_transaction_id"], name: "idx_on_expense_transaction_id_afcf50bd10"
    t.index ["transaction_subcategory_id"], name: "idx_on_transaction_subcategory_id_c2c97f8b7d"
    t.index ["user_id"], name: "index_expense_transaction_subcategories_on_user_id"
  end

  create_table "expense_transactions", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "card_last4"
    t.integer "category_id"
    t.decimal "classification_confidence", precision: 5, scale: 2
    t.text "classification_reason"
    t.datetime "classified_at"
    t.datetime "created_at", null: false
    t.string "description"
    t.string "direction"
    t.string "external_id"
    t.integer "import_batch_id"
    t.text "notes"
    t.date "occurred_on"
    t.json "raw_data"
    t.string "source"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["category_id"], name: "index_expense_transactions_on_category_id"
    t.index ["import_batch_id"], name: "index_expense_transactions_on_import_batch_id"
    t.index ["occurred_on"], name: "index_expense_transactions_on_occurred_on"
    t.index ["user_id", "external_id"], name: "index_expense_transactions_on_user_and_external_id", unique: true
    t.index ["user_id"], name: "index_expense_transactions_on_user_id"
  end

  create_table "import_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "filename"
    t.datetime "imported_at"
    t.text "notes"
    t.integer "rows_count", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.integer "transactions_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_import_batches_on_user_id"
  end

  create_table "import_rows", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "card_last4"
    t.integer "category_id"
    t.decimal "classification_confidence", precision: 4, scale: 2
    t.text "classification_reason"
    t.string "classification_status", default: "pending", null: false
    t.datetime "classified_at"
    t.datetime "created_at", null: false
    t.string "description"
    t.string "direction"
    t.string "external_id"
    t.integer "import_batch_id", null: false
    t.text "notes"
    t.date "occurred_on"
    t.json "raw_data"
    t.integer "row_number", null: false
    t.string "source"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["category_id"], name: "index_import_rows_on_category_id"
    t.index ["import_batch_id", "row_number"], name: "index_import_rows_on_import_batch_id_and_row_number", unique: true
    t.index ["import_batch_id"], name: "index_import_rows_on_import_batch_id"
    t.index ["user_id", "external_id"], name: "index_import_rows_on_user_id_and_external_id"
    t.index ["user_id"], name: "index_import_rows_on_user_id"
  end

  create_table "insight_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expense_transaction_id", null: false
    t.integer "insight_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["expense_transaction_id"], name: "index_insight_transactions_on_expense_transaction_id"
    t.index ["insight_id", "expense_transaction_id"], name: "idx_on_insight_id_expense_transaction_id_1eace887e5", unique: true
    t.index ["insight_id"], name: "index_insight_transactions_on_insight_id"
    t.index ["user_id"], name: "index_insight_transactions_on_user_id"
  end

  create_table "insights", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.string "generation_source", default: "automatic", null: false
    t.json "payload"
    t.string "severity", default: "info", null: false
    t.date "starts_on"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["generation_source"], name: "index_insights_on_generation_source"
    t.index ["starts_on", "ends_on"], name: "index_insights_on_starts_on_and_ends_on"
    t.index ["user_id"], name: "index_insights_on_user_id"
  end

  create_table "models", force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.boolean "favorite", default: false, null: false
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.boolean "user_selectable", default: false, null: false
    t.index ["family"], name: "index_models_on_family"
    t.index ["favorite"], name: "index_models_on_favorite"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
    t.index ["user_selectable"], name: "index_models_on_user_selectable"
  end

  create_table "saved_transaction_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "filters", default: {}, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_saved_transaction_queries_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_saved_transaction_queries_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transaction_subcategories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id", "name"], name: "index_transaction_subcategories_on_user_and_name", unique: true
    t.index ["user_id"], name: "index_transaction_subcategories_on_user_id"
  end

  create_table "user_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "accepted_by_user_id"
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "expires_at", null: false
    t.integer "invited_by_user_id"
    t.datetime "updated_at", null: false
    t.index ["accepted_by_user_id"], name: "index_user_invitations_on_accepted_by_user_id"
    t.index ["email_address", "accepted_at"], name: "index_user_invitations_on_email_and_accepted_at"
    t.index ["email_address"], name: "index_user_invitations_on_email_address"
    t.index ["invited_by_user_id"], name: "index_user_invitations_on_invited_by_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "csv_reminder_enabled", default: true, null: false
    t.integer "csv_reminder_hour", default: 9, null: false
    t.datetime "csv_reminder_last_sent_at"
    t.integer "csv_reminder_wday", default: 1, null: false
    t.string "email_address", null: false
    t.datetime "onboarding_dismissed_at"
    t.string "password_digest", null: false
    t.string "preferred_ai_model"
    t.boolean "retain_uploaded_csv", default: true, null: false
    t.string "role", default: "regular", null: false
    t.datetime "updated_at", null: false
    t.index ["csv_reminder_enabled", "csv_reminder_wday", "csv_reminder_hour"], name: "index_users_on_csv_reminder_schedule"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_chat_messages", "ai_chats"
  add_foreign_key "ai_chat_transactions", "ai_chats"
  add_foreign_key "ai_chat_transactions", "expense_transactions"
  add_foreign_key "ai_chats", "users"
  add_foreign_key "expense_transaction_subcategories", "expense_transactions"
  add_foreign_key "expense_transaction_subcategories", "transaction_subcategories"
  add_foreign_key "expense_transactions", "categories"
  add_foreign_key "expense_transactions", "import_batches"
  add_foreign_key "import_rows", "categories"
  add_foreign_key "import_rows", "import_batches"
  add_foreign_key "insight_transactions", "expense_transactions"
  add_foreign_key "insight_transactions", "insights"
  add_foreign_key "saved_transaction_queries", "users"
  add_foreign_key "sessions", "users"
end
