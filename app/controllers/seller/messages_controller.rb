class Seller::MessagesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_conversation

  def index
    # Get all conversations with the same buyer
    all_conversations_with_buyer = Conversation.where(
      seller_id: @current_user.id,
      buyer_id: @conversation.buyer_id
    )
    
    # Get all messages from all conversations with this buyer
    all_messages = all_conversations_with_buyer.flat_map(&:messages).sort_by(&:created_at)
    
    # Include ad information for each message
    messages_with_ads = all_messages.map do |message|
      message_data = {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender_type: message.sender_type,
        sender_id: message.sender_id,
        ad_id: message.ad_id,
        product_context: message.product_context
      }
      
      if message.ad_id
        ad = Ad.find(message.ad_id)
        message_data[:ad] = {
          id: ad.id,
          title: ad.title,
          price: ad.price,
          first_media_url: ad.media.first,
          category: ad.category&.name,
          subcategory: ad.subcategory&.name
        }
      end
      
      message_data
    end
    
    render json: {
      messages: messages_with_ads,
      total_messages: messages_with_ads.count
    }
  end

  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = @current_user
    @message.status = Message::STATUS_SENT

    if @message.save
      # Broadcast the message to all participants
      broadcast_message(@message)
      
      render json: @message.as_json(include: :sender), status: :created
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  private

  def broadcast_message(message)
    # Broadcast to buyer
    ActionCable.server.broadcast(
      "conversations_buyer_#{@conversation.buyer_id}",
      {
        type: 'new_message',
        conversation_id: @conversation.id,
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

    # Broadcast to seller
    ActionCable.server.broadcast(
      "conversations_seller_#{@conversation.seller_id}",
      {
        type: 'new_message',
        conversation_id: @conversation.id,
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

  private

  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id], seller_id: @current_user.id)
    
    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
    end
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_user&.is_a?(Seller)
  end
end