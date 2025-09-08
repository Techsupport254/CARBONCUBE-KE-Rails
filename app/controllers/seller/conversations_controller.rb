class Seller::ConversationsController < ApplicationController
  before_action :authenticate_seller

  def index
    # Fetch conversations where current seller is the seller
    @conversations = Conversation.where(seller_id: @current_seller.id)
                                .includes(:admin, :buyer, :ad, :messages)
                                .order(updated_at: :desc)
    
    # Group conversations by buyer_id to avoid duplicates
    grouped_conversations = @conversations.group_by(&:buyer_id)
    
    conversations_data = grouped_conversations.map do |buyer_id, conversations|
      # Get the most recent conversation for this buyer
      most_recent_conversation = conversations.max_by(&:updated_at)
      last_message = most_recent_conversation.messages.last
      
      {
        id: most_recent_conversation.id,
        seller_id: most_recent_conversation.seller_id,
        buyer_id: most_recent_conversation.buyer_id,
        created_at: most_recent_conversation.created_at,
        updated_at: most_recent_conversation.updated_at,
        admin: most_recent_conversation.admin,
        buyer: most_recent_conversation.buyer,
        ad: most_recent_conversation.ad,
        messages_count: conversations.sum { |c| c.messages.count },
        last_message: last_message&.content,
        last_message_time: last_message&.created_at,
        all_conversation_ids: conversations.map(&:id)
      }
    end
    
    render json: conversations_data
  end

  def show
    @conversation = Conversation.find_by(id: params[:id], seller_id: @current_seller.id)
    
    if @conversation
      # Get all conversations with the same buyer
      all_conversations_with_buyer = Conversation.where(
        seller_id: @current_seller.id,
        buyer_id: @conversation.buyer_id
      )
      
      # Get all messages from all conversations with this buyer
      all_messages = all_conversations_with_buyer.flat_map(&:messages).sort_by(&:created_at)
      
      render json: {
        conversation: @conversation,
        all_messages: all_messages,
        total_messages: all_messages.count
      }
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  end

  def create
    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      seller_id: @current_seller.id,
      buyer_id: params[:buyer_id],
      ad_id: params[:ad_id]
    ) do |conv|
      conv.admin_id = params[:admin_id] if params[:admin_id].present?
    end

    # Create the message
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_seller
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
    @conversation = Conversation.find_by(id: params[:id], seller_id: @current_seller.id)
    
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found
      return
    end

    # Add a new message to the conversation
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_seller
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

  # GET /seller/conversations/unread_counts
  def unread_counts
    # Get all conversations for the current seller with unread message counts
    conversations = Conversation.where(seller_id: @current_seller.id)
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Buyer', 'Admin'])
                                .where(status: [nil, Message::STATUS_SENT])
                                .count
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    render json: { unread_counts: unread_counts }
  end

  # GET /seller/conversations/unread_count
  def unread_count
    # Get all conversations for the current seller
    conversations = Conversation.where(seller_id: @current_seller.id)
    
    # Count unread messages (messages not sent by seller and not read)
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Buyer', 'Admin'] })
                               .where(messages: { status: [nil, Message::STATUS_SENT] })
                               .count
    
    render json: { count: unread_count }
  end

  private

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_seller&.is_a?(Seller)
  end

  def current_seller
    @current_seller
  end
end