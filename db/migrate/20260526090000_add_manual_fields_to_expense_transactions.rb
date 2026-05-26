class AddManualFieldsToExpenseTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :expense_transactions, :subcategory, :string
    add_column :expense_transactions, :notes, :text
    add_index :expense_transactions, :subcategory
  end
end
