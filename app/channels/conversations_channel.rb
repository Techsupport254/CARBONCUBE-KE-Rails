class ConversationsChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to conversations for the current user
    Rails.logger.info "📡 ConversationsChannel subscribed: user_type=#{params[:user_type]}, user_id=#{params[:user_id]}"
    stream_from "conversations_#{params[:user_type]}_#{params[:user_id]}"
    Rails.logger.info "📡 Streaming from: conversations_#{params[:user_type]}_#{params[:user_id]}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "📡 ConversationsChannel unsubscribed: user_type=#{params[:user_type]}, user_id=#{params[:user_id]}"
  end

  def receive(data)
    # Handle incoming messages
    conversation_id = data['conversation_id']
    message_content = data['content']
    sender_type = data['sender_type']
    sender_id = data['sender_id']
    
    # Find the conversation
    conversation = Conversation.find(conversation_id)
    
    # Create the message
    message = conversation.messages.create!(
      content: message_content,
      sender_type: sender_type,
      sender_id: sender_id
    )
    
    # Broadcast to all participants
    broadcast_to_participants(conversation, message)
  end

  private

  def broadcast_to_participants(conversation, message)
    # Broadcast to buyer
    if conversation.buyer_id
      ActionCable.server.broadcast(
        "conversations_buyer_#{conversation.buyer_id}",
        {
          type: 'new_message',
          conversation_id: conversation.id,
          message: {
            id: message.id,
            content: message.content,
            created_at: message.created_at,
            sender_type: message.sender_type,
            sender_id: message.sender_id,
            ad_id: message.ad_id,
            product_context: message.product_context
          }
        }
      )
    end

    # Broadcast to seller
    if conversation.seller_id
      ActionCable.server.broadcast(
        "conversations_seller_#{conversation.seller_id}",
        {
          type: 'new_message',
          conversation_id: conversation.id,
          message: {
            id: message.id,
            content: message.content,
            created_at: message.created_at,
            sender_type: message.sender_type,
            sender_id: message.sender_id,
            ad_id: message.ad_id,
            product_context: message.product_context
          }
        }
      )
    end
  end
end
