class AddPerformanceIndexesToMessagesAndConversations < ActiveRecord::Migration[7.1]
  def change
    add_index :messages, [:conversation_id, :created_at], if_not_exists: true, name: 'index_messages_on_conv_and_created_at'
    add_index :messages, [:conversation_id, :sender_id, :created_at], if_not_exists: true, name: 'index_messages_on_conv_sender_created_at'
    add_index :conversations, :updated_at, if_not_exists: true, name: 'index_conversations_on_updated_at'
    add_index :conversations, [:buyer_id, :updated_at], if_not_exists: true, name: 'index_conversations_on_buyer_and_updated_at'
    add_index :conversations, [:seller_id, :updated_at], if_not_exists: true, name: 'index_conversations_on_seller_and_updated_at'
  end
end
