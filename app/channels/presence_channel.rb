class PresenceChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to presence channel for online status and typing
    stream_from "presence_#{params[:user_type]}_#{params[:user_id]}"
    
    # Broadcast that user is online
    broadcast_online_status(true)
  end

  def unsubscribed
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
    end
  end

  private

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
    
    if user_type == 'buyer'
      Conversation.where(buyer_id: user_id)
    elsif user_type == 'seller'
      Conversation.where(seller_id: user_id)
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
