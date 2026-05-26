class ExpenseTransactionSubcategory < ApplicationRecord
  belongs_to :expense_transaction
  belongs_to :transaction_subcategory
end
