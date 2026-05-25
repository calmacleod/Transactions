class Insight < ApplicationRecord
  validates :title, :body, :severity, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
