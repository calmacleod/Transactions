class CreateAiChats < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_chats do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :model
      t.json :context_filters, default: {}, null: false

      t.timestamps
    end

    create_table :ai_chat_messages do |t|
      t.references :ai_chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :estimated_cost_microdollars, default: 0, null: false

      t.timestamps
    end

    create_table :ai_chat_transactions do |t|
      t.references :ai_chat, null: false, foreign_key: true
      t.references :expense_transaction, null: false, foreign_key: true

      t.timestamps
    end

    add_index :ai_chats, :created_at
    add_index :ai_chat_messages, [ :ai_chat_id, :created_at ]
    add_index :ai_chat_transactions, [ :ai_chat_id, :expense_transaction_id ], unique: true, name: "index_ai_chat_transactions_uniqueness"
  end
end
