class InsightTransaction < ApplicationRecord
  belongs_to :insight
  belongs_to :expense_transaction
end
