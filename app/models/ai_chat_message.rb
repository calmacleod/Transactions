class AiChatMessage < ApplicationRecord
  include UserOwned

  belongs_to :ai_chat

  validates :role, presence: true
  validates :role, inclusion: { in: %w[user assistant system tool] }
  validates :status, inclusion: { in: %w[queued thinking complete failed] }

  scope :ordered, -> { order(:created_at, :id) }
end
