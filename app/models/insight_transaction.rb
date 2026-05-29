class InsightTransaction < ApplicationRecord
  include UserOwned

  belongs_to :insight
  belongs_to :expense_transaction
end
