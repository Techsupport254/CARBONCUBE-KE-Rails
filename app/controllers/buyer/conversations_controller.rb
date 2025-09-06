class Buyer::ConversationsController < ApplicationController
  before_action :authenticate_buyer

  def index
    # Fetch conversations where current buyer is the buyer
    @conversations = Conversation.where(buyer_id: @current_user.id)
                                .includes(:admin, :seller, :ad, :messages, ad: [:category, :subcategory])
                                .order(updated_at: :desc)
    
    # Group conversations by seller and get the most recent one for each seller
    grouped_conversations = @conversations.group_by(&:seller_id)
    
    # For each seller, get the most recent conversation and combine all messages
    conversations_data = grouped_conversations.map do |seller_id, conversations|
      # Get the most recent conversation for this seller
      most_recent_conversation = conversations.max_by(&:updated_at)
      
      # Get all messages from all conversations with this seller
      all_messages = conversations.flat_map(&:messages).sort_by(&:created_at)
      last_message = all_messages.last
      
      # Get the most recent ad context (from the most recent conversation)
      current_ad = most_recent_conversation.ad
      
      {
        id: most_recent_conversation.id,
        seller_id: seller_id,
        buyer_id: most_recent_conversation.buyer_id,
        created_at: most_recent_conversation.created_at,
        updated_at: most_recent_conversation.updated_at,
        admin: most_recent_conversation.admin,
        seller: most_recent_conversation.seller,
        ad: current_ad,
        messages_count: all_messages.count,
        last_message: last_message&.content,
        last_message_time: last_message&.created_at,
        all_conversation_ids: conversations.map(&:id)
      }
    end
    
    render json: conversations_data
  end

  def show
    @conversation = Conversation.find_by(id: params[:id], buyer_id: @current_user.id)
    
    if @conversation
      # Get all conversations with the same seller
      all_conversations_with_seller = Conversation.where(
        buyer_id: @current_user.id,
        seller_id: @conversation.seller_id
      )
      
      # Get all messages from all conversations with this seller, including ad info
      all_messages = all_conversations_with_seller.flat_map(&:messages).sort_by(&:created_at)
      
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
        
        # Add ad information if the message has an ad_id
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
        conversation: @conversation,
        messages: messages_with_ads,
        total_messages: messages_with_ads.count
      }
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  end

  def create
    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      buyer_id: @current_user.id,
      seller_id: params[:seller_id],
      ad_id: params[:ad_id]
    ) do |conv|
      conv.admin_id = params[:admin_id] if params[:admin_id].present?
      # If seller_id is not provided but ad_id is, get seller_id from the ad
      if params[:seller_id].blank? && params[:ad_id].present?
        ad = Ad.find(params[:ad_id])
        conv.seller_id = ad.seller_id
      end
    end

    # Create the message
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_user
    )

    # Return the conversation with the new message
    render json: {
      conversation_id: @conversation.id,
      message: {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender_type: message.sender.class.name,
        sender_id: message.sender.id
      }
    }, status: :created
  end

  def update
    @conversation = Conversation.find_by(id: params[:id], buyer_id: @current_user.id)
    
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end

    # Add a new message to the conversation
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_user
    )

    render json: {
      conversation_id: @conversation.id,
      message: {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        sender_type: message.sender.class.name,
        sender_id: message.sender.id
      }
    }, status: :created
  end

  # GET /buyer/conversations/unread_counts
  def unread_counts
    # Get all conversations for the current buyer with unread message counts
    conversations = Conversation.where(buyer_id: @current_user.id)
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Admin'])
                                .where(status: [nil, Message::STATUS_SENT])
                                .count
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    render json: { unread_counts: unread_counts }
  end

  # GET /buyer/conversations/unread_count
  def unread_count
    # Get all conversations for the current buyer
    conversations = Conversation.where(buyer_id: @current_user.id)
    
    # Count unread messages (messages not sent by buyer and not read)
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Seller', 'Admin'] })
                               .where(messages: { status: [nil, Message::STATUS_SENT] })
                               .count
    
    render json: { count: unread_count }
  end

  private

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    
    if @current_user.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end