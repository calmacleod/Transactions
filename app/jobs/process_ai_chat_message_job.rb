class ProcessAiChatMessageJob < ApplicationJob
  queue_as :default

  def perform(chat_id, assistant_message_id)
    chat = AiChat.find(chat_id)
    assistant_message = chat.messages.find(assistant_message_id)

    assistant_message.update!(status: "thinking")
    AiChatChannel.broadcast_message_update(chat, assistant_message)

    Ai::TransactionChat.new.respond_to_chat(chat:, assistant_message:)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
