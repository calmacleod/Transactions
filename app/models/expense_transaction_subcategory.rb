class ExpenseTransactionSubcategory < ApplicationRecord
  include UserOwned

  belongs_to :expense_transaction
  belongs_to :transaction_subcategory
end
