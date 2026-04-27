class AddPerformanceIndexesForJobs < ActiveRecord::Migration[7.1]
  def up
    # Add indexes for conversations table to optimize unread count queries
    add_index :conversations, [:buyer_id, :seller_id], name: 'index_conversations_buyer_seller'
    add_index :conversations, [:seller_id, :inquirer_seller_id], name: 'index_conversations_seller_inquirer'
    add_index :conversations, [:admin_id, :seller_id], name: 'index_conversations_admin_seller'
    
    # Add composite indexes for messages table to optimize unread count queries
    add_index :messages, [:conversation_id, :sender_type, :read_at], name: 'index_messages_conversation_sender_read'
    add_index :messages, [:conversation_id, :sender_id, :read_at], name: 'index_messages_conversation_senderid_read'
    add_index :messages, [:conversation_id, :read_at], name: 'index_messages_conversation_read'
    add_index :messages, :read_at, name: 'index_messages_read_at'
    add_index :messages, :sender_type, name: 'index_messages_sender_type'
    
    # Add indexes for sellers to optimize analytics queries
    add_index :ads, :seller_id, name: 'index_ads_seller_id'
    add_index :reviews, :seller_id, name: 'index_reviews_seller_id'
    
    # Add index for conversations unique constraint to speed up find_or_create_by
    add_index :conversations, 
              [:admin_id, :seller_id, :ad_id, :buyer_id, :inquirer_seller_id], 
              name: 'index_conversations_unique_lookup',
              unique: true
  end

  def down
    # Remove indexes in reverse order
    remove_index :conversations, name: 'index_conversations_unique_lookup'
    remove_index :reviews, name: 'index_reviews_seller_id'
    remove_index :ads, name: 'index_ads_seller_id'
    remove_index :messages, name: 'index_messages_sender_type'
    remove_index :messages, name: 'index_messages_read_at'
    remove_index :messages, name: 'index_messages_conversation_read'
    remove_index :messages, name: 'index_messages_conversation_senderid_read'
    remove_index :messages, name: 'index_messages_conversation_sender_read'
    remove_index :conversations, name: 'index_conversations_admin_seller'
    remove_index :conversations, name: 'index_conversations_seller_inquirer'
    remove_index :conversations, name: 'index_conversations_buyer_seller'
  end
end
