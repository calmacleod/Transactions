class ExpenseTransaction < ApplicationRecord
  belongs_to :category, optional: true
  belongs_to :import_batch, optional: true
  has_many :expense_transaction_subcategories, dependent: :destroy
  has_many :subcategories, through: :expense_transaction_subcategories, source: :transaction_subcategory

  validates :occurred_on, :description, :amount_cents, :direction, :external_id, presence: true
  validates :external_id, uniqueness: true
  validates :direction, inclusion: { in: %w[debit credit] }

  scope :recent, -> { order(occurred_on: :desc, id: :desc) }
  scope :expenses, -> { where(direction: "debit") }
  scope :credits, -> { where(direction: "credit") }
  scope :unclassified, -> { where(category_id: nil) }
  scope :between, ->(start_date, end_date) { where(occurred_on: start_date..end_date) }

  def self.group_by_month
    group("strftime('%Y-%m-01', occurred_on)").sum(:amount_cents).transform_keys { |month| Date.iso8601(month) }
  end

  def amount
    amount_cents.to_d / 100
  end

  def merchant_name
    description_parts.first.to_s.squish.presence || description
  end

  def description_detail
    description_parts.second.to_s.sub(/\A[#*\s]+/, "").squish
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

  private

  def description_parts
    description.to_s.split(/\s{2,}| #|\*/, 2)
  end
end
