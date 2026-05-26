require "test_helper"

class AiChatsControllerTest < ActionDispatch::IntegrationTest
  test "lists saved chats for the current user" do
    sign_in_as users(:one)
    older_chat = users(:one).ai_chats.create!(title: "Older chat", updated_at: 2.days.ago)
    recent_chat = users(:one).ai_chats.create!(title: "Recent chat", updated_at: 1.hour.ago)
    recent_chat.messages.create!(role: "user", content: "What changed?", status: "complete")
    recent_chat.expense_transactions << expense_transactions(:grocery)
    users(:two).ai_chats.create!(title: "Other user's chat")

    get ai_chats_path

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ recent_chat.id, older_chat.id ], body.fetch("chats").map { |chat| chat.fetch("id") }
    assert_equal "What changed?", body.fetch("chats").first.fetch("last_message")
    assert_equal 1, body.fetch("chats").first.fetch("transaction_count")
  end

  test "shows a saved chat with messages and attached transaction ids" do
    sign_in_as users(:one)
    chat = users(:one).ai_chats.create!(title: "Saved transaction chat")
    chat.messages.create!(role: "user", content: "Summarize this", status: "complete")
    chat.messages.create!(
      role: "assistant",
      content: "This includes [[transaction:#{expense_transactions(:grocery).id}]].",
      status: "complete",
      metadata: { referenced_transaction_ids: [ expense_transactions(:grocery).id ] }
    )
    chat.expense_transactions << expense_transactions(:grocery)

    get ai_chat_path(chat)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal chat.id, body.fetch("id")
    assert_equal [ expense_transactions(:grocery).id ], body.fetch("transaction_ids")
    assert_equal [ "Summarize this", "This includes [[transaction:#{expense_transactions(:grocery).id}]]." ], body.fetch("messages").map { |message| message.fetch("content") }
    assert_equal [ expense_transactions(:grocery).id ], body.fetch("referenced_transactions").map { |transaction| transaction.fetch("id") }
  end

  test "does not show another user's chat" do
    sign_in_as users(:one)
    chat = users(:two).ai_chats.create!(title: "Other user's chat")

    get ai_chat_path(chat)

    assert_response :not_found
  end
end
