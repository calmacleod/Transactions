class Category < ApplicationRecord
  has_many :expense_transactions, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :by_name, -> { order(:name) }
end
