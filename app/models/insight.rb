class Insight < ApplicationRecord
  has_many :insight_transactions, dependent: :destroy
  has_many :expense_transactions, through: :insight_transactions

  validates :title, :body, :severity, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
