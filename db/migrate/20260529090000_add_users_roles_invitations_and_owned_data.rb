class AddUsersRolesInvitationsAndOwnedData < ActiveRecord::Migration[8.1]
  OWNED_TABLES = %i[
    ai_requests
    categories
    classification_runs
    expense_transactions
    import_batches
    insights
    transaction_subcategories
  ].freeze

  def change
    change_table :users, bulk: true do |t|
      t.string :role, default: "regular", null: false
      t.datetime :onboarding_dismissed_at
      t.boolean :csv_reminder_enabled, default: true, null: false
      t.integer :csv_reminder_wday, default: 1, null: false
      t.integer :csv_reminder_hour, default: 9, null: false
      t.datetime :csv_reminder_last_sent_at
    end

    add_index :users, :role
    add_index :users, [ :csv_reminder_enabled, :csv_reminder_wday, :csv_reminder_hour ], name: "index_users_on_csv_reminder_schedule"

    OWNED_TABLES.each do |table|
      add_reference table, :user, null: true, foreign_key: false, index: true
    end

    remove_index :categories, :name, if_exists: true
    add_index :categories, [ :user_id, :name ], unique: true

    remove_index :transaction_subcategories, :name, if_exists: true
    add_index :transaction_subcategories, [ :user_id, :name ], unique: true, name: "index_transaction_subcategories_on_user_and_name"

    remove_index :expense_transactions, :external_id, if_exists: true
    add_index :expense_transactions, [ :user_id, :external_id ], unique: true, name: "index_expense_transactions_on_user_and_external_id"

    create_table :user_invitations do |t|
      t.string :email_address, null: false
      t.string :code_digest, null: false
      t.integer :invited_by_user_id
      t.integer :accepted_by_user_id
      t.datetime :accepted_at
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :user_invitations, :email_address
    add_index :user_invitations, :invited_by_user_id
    add_index :user_invitations, :accepted_by_user_id
    add_index :user_invitations, [ :email_address, :accepted_at ], name: "index_user_invitations_on_email_and_accepted_at"

    reversible do |dir|
      dir.up { backfill_existing_records }
    end
  end

  private

  def backfill_existing_records
    first_user_id = select_value("SELECT id FROM users ORDER BY id LIMIT 1")
    return if first_user_id.blank?

    timestamp = quote(Time.current)
    execute("UPDATE users SET role = 'admin', onboarding_dismissed_at = COALESCE(onboarding_dismissed_at, #{timestamp}) WHERE id = #{first_user_id}")

    OWNED_TABLES.each do |table|
      execute("UPDATE #{table} SET user_id = #{first_user_id} WHERE user_id IS NULL")
    end
  end
end
