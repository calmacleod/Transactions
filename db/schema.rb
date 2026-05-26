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

ActiveRecord::Schema[8.1].define(version: 2026_05_26_090004) do
  create_table "ai_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "estimated_cost_cents", default: 0, null: false
    t.string "feature", null: false
    t.integer "input_tokens"
    t.string "model"
    t.integer "output_tokens"
    t.boolean "successful", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_requests_on_created_at"
    t.index ["feature"], name: "index_ai_requests_on_feature"
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
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "classification_runs", force: :cascade do |t|
    t.string "active_job_id"
    t.integer "ai_count", default: 0, null: false
    t.datetime "cancel_requested_at"
    t.integer "classified_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "failed_count", default: 0, null: false
    t.datetime "finished_at"
    t.text "notes"
    t.integer "processed_count", default: 0, null: false
    t.integer "rule_based_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_classification_runs_on_created_at"
    t.index ["status"], name: "index_classification_runs_on_status"
  end

  create_table "expense_transaction_subcategories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expense_transaction_id", null: false
    t.integer "transaction_subcategory_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_transaction_id", "transaction_subcategory_id"], name: "index_expense_transaction_subcategories_uniqueness", unique: true
    t.index ["expense_transaction_id"], name: "idx_on_expense_transaction_id_afcf50bd10"
    t.index ["transaction_subcategory_id"], name: "idx_on_transaction_subcategory_id_c2c97f8b7d"
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
    t.index ["category_id"], name: "index_expense_transactions_on_category_id"
    t.index ["external_id"], name: "index_expense_transactions_on_external_id", unique: true
    t.index ["import_batch_id"], name: "index_expense_transactions_on_import_batch_id"
    t.index ["occurred_on"], name: "index_expense_transactions_on_occurred_on"
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
    t.index ["generation_source"], name: "index_insights_on_generation_source"
    t.index ["starts_on", "ends_on"], name: "index_insights_on_starts_on_and_ends_on"
  end

  create_table "models", force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
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
    t.index ["family"], name: "index_models_on_family"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
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
    t.index ["name"], name: "index_transaction_subcategories_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "expense_transaction_subcategories", "expense_transactions"
  add_foreign_key "expense_transaction_subcategories", "transaction_subcategories"
  add_foreign_key "expense_transactions", "categories"
  add_foreign_key "expense_transactions", "import_batches"
  add_foreign_key "saved_transaction_queries", "users"
  add_foreign_key "sessions", "users"
end
