class CreateInsightTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :insight_transactions do |t|
      t.references :insight, null: false, foreign_key: true
      t.references :expense_transaction, null: false, foreign_key: true

      t.timestamps
    end

    add_index :insight_transactions, [ :insight_id, :expense_transaction_id ], unique: true
  end
end
