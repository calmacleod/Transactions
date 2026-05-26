class AiRequest < ApplicationRecord
  validates :feature, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(created_at: Date.current.beginning_of_month..) }
  scope :successful, -> { where(successful: true) }
end
