class TransactionSubcategory < ApplicationRecord
  include UserOwned

  has_many :expense_transaction_subcategories, dependent: :destroy
  has_many :expense_transactions, through: :expense_transaction_subcategories

  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :user_id }

  scope :by_name, -> { order(:name) }
end
