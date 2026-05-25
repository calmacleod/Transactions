class SavedTransactionQuery < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :filters, presence: true

  scope :ordered, -> { order(:name) }
end
