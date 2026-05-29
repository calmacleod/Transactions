class ImportRow < ApplicationRecord
  include UserOwned

  belongs_to :import_batch
  belongs_to :category, optional: true

  validates :row_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :occurred_on, :description, :amount_cents, :direction, :external_id, presence: true
  validates :direction, inclusion: { in: %w[debit credit] }

  scope :ordered, -> { order(:row_number, :id) }

  def classified?
    category_id.present?
  end

  def transaction_attributes
    {
      occurred_on:,
      description:,
      amount_cents:,
      direction:,
      card_last4:,
      source:,
      raw_data: raw_data || {},
      external_id:,
      category_id:,
      notes:
    }
  end
end
