class Insight < ApplicationRecord
  include UserOwned

  KINDS = %w[budget_pace category_shift new_spend merchant_frequency unusual_transaction recurring_commitment data_quality observation].freeze

  has_many :insight_transactions, dependent: :destroy
  has_many :expense_transactions, through: :insight_transactions

  validates :title, :body, :action, :severity, :kind, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :recent, -> { order(created_at: :desc) }
end
