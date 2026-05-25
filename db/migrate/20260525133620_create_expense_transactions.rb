class CreateExpenseTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_transactions do |t|
      t.date :occurred_on
      t.string :description
      t.integer :amount_cents
      t.string :direction
      t.string :card_last4
      t.string :source
      t.references :category, null: true, foreign_key: true
      t.decimal :classification_confidence, precision: 5, scale: 2
      t.text :classification_reason
      t.datetime :classified_at
      t.string :external_id
      t.json :raw_data
      t.references :import_batch, null: true, foreign_key: true

      t.timestamps
    end

    add_index :expense_transactions, :occurred_on
    add_index :expense_transactions, :external_id, unique: true
  end
end
