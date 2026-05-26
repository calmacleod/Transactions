class AiChatTransaction < ApplicationRecord
  belongs_to :ai_chat
  belongs_to :expense_transaction
end
