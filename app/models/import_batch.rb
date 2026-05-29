class ImportBatch < ApplicationRecord
  include UserOwned

  UNFINISHED_STATUSES = %w[preview processing failed].freeze

  has_many :expense_transactions, dependent: :nullify
  has_many :import_rows, dependent: :destroy
  has_one_attached :source_file

  validates :filename, presence: true
  validates :status, presence: true

  scope :unfinished, -> { where(status: UNFINISHED_STATUSES).order(created_at: :desc) }
  scope :complete, -> { where(status: "complete") }

  def unfinished?
    status.in?(UNFINISHED_STATUSES)
  end

  def complete?
    status == "complete"
  end

  def source_file_retained?
    source_file.attached?
  end
end
