class AiChatsController < ApplicationController
  def index
    chats = Current.session.user.ai_chats.recent.includes(:messages, :expense_transactions).limit(50)

    render json: {
      chats: chats.map { |chat| chat_summary_props(chat) }
    }
  end

  def show
    chat = Current.session.user.ai_chats.find(params[:id])

    render json: chat_props(chat)
  end

  private

  def chat_props(chat)
    {
      id: chat.id,
      title: chat.title,
      model: chat.model,
      transaction_count: chat.expense_transactions.count,
      transaction_ids: chat.expense_transaction_ids,
      transactions: chat.expense_transactions.includes(:category, :subcategories).recent.limit(100).map { |transaction| transaction_props(transaction) },
      referenced_transactions: referenced_transactions(chat).map { |transaction| transaction_props(transaction) },
      messages: chat.messages.ordered.map { |message| message_props(message) }
    }
  end

  def chat_summary_props(chat)
    messages = chat.messages.sort_by { |message| [ message.created_at, message.id ] }
    last_message = messages.reverse.find { |message| message.content.present? }

    {
      id: chat.id,
      title: chat.title,
      model: chat.model,
      transaction_count: chat.expense_transactions.size,
      message_count: messages.size,
      last_message: last_message&.content.to_s.truncate(160),
      updated_at: chat.updated_at.iso8601,
      updated_at_label: "#{helpers.time_ago_in_words(chat.updated_at)} ago"
    }
  end

  def message_props(message)
    AiChatChannel.message_payload(message)
  end

  def referenced_transactions(chat)
    ids = chat.messages.flat_map do |message|
      metadata_ids = Array(message.metadata&.fetch("referenced_transaction_ids", []))
      content_ids = message.content.to_s.scan(/\[\[transaction:(\d+)\]\]/i).flatten

      metadata_ids + content_ids
    end.map(&:to_i).uniq

    return ExpenseTransaction.none if ids.empty?

    ExpenseTransaction.where(id: ids).includes(:category, :subcategories).recent
  end
end
