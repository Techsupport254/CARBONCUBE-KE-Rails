class PresenceChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "PresenceChannel subscribed: user_type=#{params[:user_type]}, user_id=#{params[:user_id]}"
    
    # Subscribe to presence channel for online status and typing
    stream_from "presence_#{params[:user_type]}_#{params[:user_id]}"
    
    # Track this user as online in Redis or similar
    track_user_online(true)
    
    # Broadcast that user is online
    broadcast_online_status(true)
  end

  def unsubscribed
    # Track this user as offline
    track_user_online(false)
    
    # Broadcast that user is offline
    broadcast_online_status(false)
  end

  def receive(data)
    case data['type']
    when 'typing_start'
      broadcast_typing_status(true, data['conversation_id'])
    when 'typing_stop'
      broadcast_typing_status(false, data['conversation_id'])
    when 'message_read'
      handle_message_read(data['message_id'])
    when 'message_delivered'
      handle_message_delivered(data['message_id'])
    when 'heartbeat'
      # Update user's online status
      track_user_online(true)
    end
  end

  private

  def track_user_online(online)
    # Use Rails cache to track online users
    # Key format: "online_user_#{user_type}_#{user_id}"
    cache_key = "online_user_#{params[:user_type]}_#{params[:user_id]}"
    
    Rails.logger.info "Tracking user online: #{cache_key} = #{online}"
    
    if online
      # Set user as online with a 5-minute expiration
      Rails.cache.write(cache_key, true, expires_in: 5.minutes)
    else
      # Remove user from online tracking
      Rails.cache.delete(cache_key)
    end
  end

  def broadcast_online_status(online)
    # Get user's conversations
    conversations = get_user_conversations
    
    conversations.each do |conversation|
      # Broadcast to other participants
      broadcast_to_other_participants(conversation, {
        type: 'online_status',
        user_id: params[:user_id],
        user_type: params[:user_type],
        online: online
      })
    end
  end

  def broadcast_typing_status(typing, conversation_id)
    # Find the specific conversation
    conversation = Conversation.find(conversation_id)
    
    # Broadcast to other participants in this conversation only
    broadcast_to_other_participants(conversation, {
      type: 'typing_status',
      user_id: params[:user_id],
      user_type: params[:user_type],
      typing: typing,
      conversation_id: conversation_id
    })
  end

  def handle_message_read(message_id)
    message = Message.find(message_id)
    
    # Update message read status
    message.update(read_at: Time.current, status: 'read')
    
    # Broadcast read receipt to sender
    broadcast_read_receipt(message)
  end

  def handle_message_delivered(message_id)
    message = Message.find(message_id)
    
    # Update message delivered status
    message.update(delivered_at: Time.current, status: 'delivered')
    
    # Broadcast delivery receipt to sender
    broadcast_delivery_receipt(message)
  end

  def get_user_conversations
    user_id = params[:user_id].to_i
    user_type = params[:user_type]
    
    case user_type.downcase
    when 'buyer'
      Conversation.where(buyer_id: user_id)
    when 'seller'
      Conversation.where(seller_id: user_id)
    when 'admin'
      # Admins can see all conversations, but we need to find conversations where they participate
      Conversation.where("buyer_id = ? OR seller_id = ? OR admin_id = ?", user_id, user_id, user_id)
    else
      []
    end
  end

  def broadcast_to_other_participants(conversation, data)
    # Broadcast to buyer (but not to self)
    if conversation.buyer_id && conversation.buyer_id.to_s != params[:user_id]
      ActionCable.server.broadcast(
        "presence_buyer_#{conversation.buyer_id}",
        data
      )
    end

    # Broadcast to seller (but not to self)
    if conversation.seller_id && conversation.seller_id.to_s != params[:user_id]
      ActionCable.server.broadcast(
        "presence_seller_#{conversation.seller_id}",
        data
      )
    end

    # Broadcast to admin (but not to self)
    if conversation.admin_id && conversation.admin_id.to_s != params[:user_id]
      ActionCable.server.broadcast(
        "presence_admin_#{conversation.admin_id}",
        data
      )
    end
  end

  def broadcast_read_receipt(message)
    # Broadcast to message sender
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    ActionCable.server.broadcast(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_read',
        message_id: message.id,
        conversation_id: message.conversation_id,
        read_at: message.read_at
      }
    )
  end

  def broadcast_delivery_receipt(message)
    # Broadcast to message sender
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    ActionCable.server.broadcast(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_delivered',
        message_id: message.id,
        conversation_id: message.conversation_id,
        delivered_at: message.delivered_at
      }
    )
  end
end
