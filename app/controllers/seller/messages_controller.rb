class Seller::MessagesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_conversation

  def index
    # Get all conversations with the same participant (buyer or inquirer_seller)
    if @conversation.buyer_id.present?
      # Regular buyer conversation
      all_conversations_with_participant = Conversation.where(
        seller_id: @current_user.id,
        buyer_id: @conversation.buyer_id
      )
    elsif @conversation.inquirer_seller_id.present? && @conversation.seller_id == @current_user.id
      # Current user is the ad owner, inquirer_seller is the other participant
      all_conversations_with_participant = Conversation.where(
        seller_id: @current_user.id,
        inquirer_seller_id: @conversation.inquirer_seller_id
      )
    else
      # Current user is the inquirer_seller, seller is the other participant
      all_conversations_with_participant = Conversation.where(
        seller_id: @conversation.seller_id,
        inquirer_seller_id: @current_user.id
      )
    end
    
    # Get all messages from all conversations with this participant
    all_messages = all_conversations_with_participant.flat_map(&:messages).sort_by(&:created_at)
    
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
      # Update seller's last active timestamp when sending a message
      @current_user.update_last_active!
      # Message broadcasting is handled by the Message model's after_create callback
      render json: @message.as_json(include: :sender), status: :created
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    # Find conversation where current seller is either the seller or the inquirer_seller
    @conversation = Conversation.where(
      id: params[:conversation_id]
    ).where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    ).first
    
    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
    end
  end

  def message_params
    params.require(:message).permit(:content, :ad_id)
  end

  def authenticate_seller
    @current_user = SellerAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_user&.is_a?(Seller)
  end
end