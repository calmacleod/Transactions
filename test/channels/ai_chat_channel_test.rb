require "test_helper"

class AiChatChannelTest < ActionCable::Channel::TestCase
  test "subscribes to a chat owned by the current user" do
    chat = users(:one).ai_chats.create!(title: "Test chat")

    stub_connection current_user: users(:one)
    subscribe chat_id: chat.id

    assert subscription.confirmed?
    assert_has_stream_for chat
  end

  test "rejects chats owned by another user" do
    chat = users(:two).ai_chats.create!(title: "Other chat")

    stub_connection current_user: users(:one)
    subscribe chat_id: chat.id

    assert subscription.rejected?
  end
end
