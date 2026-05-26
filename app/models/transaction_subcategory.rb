class TransactionSubcategory < ApplicationRecord
  has_many :expense_transaction_subcategories, dependent: :destroy
  has_many :expense_transactions, through: :expense_transaction_subcategories

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :by_name, -> { order(:name) }
end
