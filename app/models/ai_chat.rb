class AiChat < ApplicationRecord
  belongs_to :user
  has_many :messages, class_name: "AiChatMessage", dependent: :destroy
  has_many :ai_chat_transactions, dependent: :destroy
  has_many :expense_transactions, through: :ai_chat_transactions

  validates :title, presence: true

  scope :recent, -> { order(updated_at: :desc) }
end
