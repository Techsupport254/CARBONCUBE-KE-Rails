class MessagesController < ApplicationController
  before_action :authenticate_user
  before_action :set_conversation

  def index
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_messages
    when 'Seller'
      fetch_seller_messages
    when 'Admin'
      fetch_admin_messages
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def create
    @message = @conversation.messages.build(message_params)
    @message.sender = @current_user
    
    # Set appropriate status based on user type
    if @current_user.is_a?(Buyer) || @current_user.is_a?(Seller)
      @message.status = Message::STATUS_SENT
    end

    if @message.save
      # Message broadcasting is handled by the Message model's after_create callback
      render json: @message.as_json(include: :sender), status: :created
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  private

  def authenticate_user
    # Try authenticating as different user types
    @current_user = authenticate_seller || authenticate_buyer || authenticate_admin
    
    unless @current_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def authenticate_seller
    SellerAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_buyer
    BuyerAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_admin
    AdminAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def set_conversation
    @conversation = case @current_user.class.name
                   when 'Buyer'
                     find_buyer_conversation
                   when 'Seller'
                     find_seller_conversation
                   when 'Admin'
                     find_admin_conversation
                   end

    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
    end
  end

  def find_buyer_conversation
    Conversation.find_by(id: params[:conversation_id], buyer_id: @current_user.id)
  end

  def find_seller_conversation
    # Find conversation where current seller is either the seller or the inquirer_seller
    Conversation.where(
      id: params[:conversation_id]
    ).where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    ).first
  end

  def find_admin_conversation
    # Admins can access any conversation
    Conversation.find_by(id: params[:conversation_id])
  end

  def fetch_buyer_messages
    # Get all conversations with the same seller
    all_conversations_with_seller = Conversation.where(
      buyer_id: @current_user.id,
      seller_id: @conversation.seller_id
    )
    
    # Get all messages from all conversations with this seller, including ad info
    all_messages = all_conversations_with_seller.flat_map(&:messages).sort_by(&:created_at)
    
    # Include ad information for each message
    messages_with_ads = all_messages.map do |message|
      message_data = build_message_data(message)
      add_ad_information(message_data, message)
      message_data
    end
    
    render json: {
      messages: messages_with_ads,
      total_messages: messages_with_ads.count
    }
  end

  def fetch_seller_messages
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
      message_data = build_message_data(message)
      add_ad_information(message_data, message)
      message_data
    end
    
    render json: {
      messages: messages_with_ads,
      total_messages: messages_with_ads.count
    }
  end

  def fetch_admin_messages
    @messages = @conversation.messages.includes(:sender).order(created_at: :asc)
    render json: @messages, each_serializer: MessageSerializer
  end

  def build_message_data(message)
    {
      id: message.id,
      content: message.content,
      created_at: message.created_at,
      sender_type: message.sender_type,
      sender_id: message.sender_id,
      ad_id: message.ad_id,
      product_context: message.product_context
    }
  end

  def add_ad_information(message_data, message)
    if message.ad_id
      ad = Ad.find(message.ad_id)
      message_data[:ad] = {
        id: ad.id,
        title: ad.title,
        price: ad.price,
        first_media_url: ad.first_media_url,
        media_urls: ad.media_urls,
        category: ad.category&.name,
        subcategory: ad.subcategory&.name
      }
    end
  end

  def message_params
    params.require(:message).permit(:content, :ad_id)
  end
end
