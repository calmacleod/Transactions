class ExpenseTransaction < ApplicationRecord
  belongs_to :category, optional: true
  belongs_to :import_batch, optional: true

  validates :occurred_on, :description, :amount_cents, :direction, :external_id, presence: true
  validates :external_id, uniqueness: true
  validates :direction, inclusion: { in: %w[debit credit] }

  scope :recent, -> { order(occurred_on: :desc, id: :desc) }
  scope :expenses, -> { where(direction: "debit") }
  scope :credits, -> { where(direction: "credit") }
  scope :unclassified, -> { where(category_id: nil) }
  scope :between, ->(start_date, end_date) { where(occurred_on: start_date..end_date) }

  def amount
    amount_cents.to_d / 100
  end

  def signed_amount_cents
    direction == "credit" ? -amount_cents : amount_cents
  end

  def expense?
    direction == "debit"
  end

  def classified?
    category_id.present?
  end
end
