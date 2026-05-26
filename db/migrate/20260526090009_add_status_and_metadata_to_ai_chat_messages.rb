class AddStatusAndMetadataToAiChatMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_chat_messages, :status, :string, default: "complete", null: false
    add_column :ai_chat_messages, :metadata, :json, default: {}, null: false
    add_index :ai_chat_messages, :status
  end
end
