class AddUserToUserOwnedJoinRecords < ActiveRecord::Migration[8.1]
  JOIN_TABLES = %i[
    ai_chat_messages
    ai_chat_transactions
    expense_transaction_subcategories
    insight_transactions
  ].freeze

  def change
    JOIN_TABLES.each do |table|
      add_reference table, :user, null: true, foreign_key: false, index: true
    end

    reversible do |dir|
      dir.up { backfill_existing_records }
    end
  end

  private

  def backfill_existing_records
    execute <<~SQL.squish
      UPDATE ai_chat_messages
      SET user_id = (
        SELECT ai_chats.user_id
        FROM ai_chats
        WHERE ai_chats.id = ai_chat_messages.ai_chat_id
      )
      WHERE user_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE ai_chat_transactions
      SET user_id = (
        SELECT ai_chats.user_id
        FROM ai_chats
        WHERE ai_chats.id = ai_chat_transactions.ai_chat_id
      )
      WHERE user_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE expense_transaction_subcategories
      SET user_id = (
        SELECT expense_transactions.user_id
        FROM expense_transactions
        WHERE expense_transactions.id = expense_transaction_subcategories.expense_transaction_id
      )
      WHERE user_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE insight_transactions
      SET user_id = (
        SELECT insights.user_id
        FROM insights
        WHERE insights.id = insight_transactions.insight_id
      )
      WHERE user_id IS NULL
    SQL
  end
end
