class CreateTransactionSubcategories < ActiveRecord::Migration[8.1]
  def up
    create_table :transaction_subcategories do |t|
      t.string :name, null: false
      t.string :color

      t.timestamps
    end

    add_index :transaction_subcategories, :name, unique: true

    create_table :expense_transaction_subcategories do |t|
      t.references :expense_transaction, null: false, foreign_key: true
      t.references :transaction_subcategory, null: false, foreign_key: true

      t.timestamps
    end

    add_index :expense_transaction_subcategories,
      [ :expense_transaction_id, :transaction_subcategory_id ],
      unique: true,
      name: "index_expense_transaction_subcategories_uniqueness"

    execute <<~SQL.squish
      INSERT INTO transaction_subcategories (name, color, created_at, updated_at)
      SELECT DISTINCT subcategory, '#71717a', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM expense_transactions
      WHERE subcategory IS NOT NULL AND subcategory != ''
    SQL

    execute <<~SQL.squish
      INSERT INTO expense_transaction_subcategories (expense_transaction_id, transaction_subcategory_id, created_at, updated_at)
      SELECT expense_transactions.id, transaction_subcategories.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM expense_transactions
      INNER JOIN transaction_subcategories ON transaction_subcategories.name = expense_transactions.subcategory
      WHERE expense_transactions.subcategory IS NOT NULL AND expense_transactions.subcategory != ''
    SQL

    remove_index :expense_transactions, :subcategory
    remove_column :expense_transactions, :subcategory
  end

  def down
    add_column :expense_transactions, :subcategory, :string
    add_index :expense_transactions, :subcategory

    execute <<~SQL.squish
      UPDATE expense_transactions
      SET subcategory = (
        SELECT transaction_subcategories.name
        FROM expense_transaction_subcategories
        INNER JOIN transaction_subcategories ON transaction_subcategories.id = expense_transaction_subcategories.transaction_subcategory_id
        WHERE expense_transaction_subcategories.expense_transaction_id = expense_transactions.id
        ORDER BY transaction_subcategories.name ASC
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1
        FROM expense_transaction_subcategories
        WHERE expense_transaction_subcategories.expense_transaction_id = expense_transactions.id
      )
    SQL

    drop_table :expense_transaction_subcategories
    drop_table :transaction_subcategories
  end
end
