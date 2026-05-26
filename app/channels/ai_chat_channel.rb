class AiChatChannel < ApplicationCable::Channel
  def subscribed
    chat = current_user.ai_chats.find_by(id: params[:chat_id])

    if chat.present?
      stream_for chat
    else
      reject
    end
  end

  def self.broadcast_message(chat, message)
    broadcast_to(chat, { type: "message", message: message_payload(message) })
  end

  def self.broadcast_message_update(chat, message)
    broadcast_to(chat, { type: "message_update", message: message_payload(message) })
  end

  def self.broadcast_tool_call(chat, message, tool_call)
    broadcast_to(
      chat,
      {
        type: "tool_call",
        message_id: message.id,
        tool_call: {
          id: tool_call.id,
          name: tool_call.name,
          arguments: tool_call.arguments
        }
      }
    )
  end

  def self.broadcast_tool_result(chat, message, result)
    broadcast_to(
      chat,
      {
        type: "tool_result",
        message_id: message.id,
        tool_result: result
      }
    )
  end

  def self.message_payload(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      status: message.status,
      metadata: message.metadata || {},
      created_at: message.created_at.iso8601
    }
  end
end
