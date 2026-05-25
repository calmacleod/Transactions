class ImportBatch < ApplicationRecord
  has_many :expense_transactions, dependent: :nullify

  validates :filename, presence: true
  validates :status, presence: true
end
