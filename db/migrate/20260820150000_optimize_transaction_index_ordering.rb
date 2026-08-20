class OptimizeTransactionIndexOrdering < ActiveRecord::Migration[8.1]
  def change
    add_index :expense_transactions,
      [ :user_id, :occurred_on, :id ],
      name: "index_expense_transactions_on_user_date_and_id"
    remove_index :expense_transactions, name: "index_expense_transactions_on_user_id"
  end
end
