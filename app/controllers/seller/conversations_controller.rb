class Seller::ConversationsController < ApplicationController
  before_action :authenticate_seller

  def index
    # Fetch conversations where current seller is either the seller, buyer, or inquirer_seller
    @conversations = Conversation.where(
      "(seller_id = ? OR buyer_id = ? OR inquirer_seller_id = ?)", 
      @current_seller.id, 
      @current_seller.id,
      @current_seller.id
    ).active_participants
     .includes(:admin, :buyer, :seller, :inquirer_seller, :ad, :messages)
     .order(updated_at: :desc)
    
    # Group conversations by the other participant (not current seller)
    grouped_conversations = @conversations.group_by do |conv|
      if conv.seller_id == @current_seller.id
        # Current seller is the ad owner, group by the inquirer
        if conv.buyer_id.present?
          "buyer_#{conv.buyer_id}"
        elsif conv.inquirer_seller_id.present?
          "inquirer_seller_#{conv.inquirer_seller_id}"
        elsif conv.admin_id.present?
          # Admin-initiated conversation with seller
          "admin_#{conv.admin_id}"
        else
          # Fallback: no participant
          "unknown_#{conv.id}"
        end
      elsif conv.inquirer_seller_id == @current_seller.id
        # Current seller is the inquirer, group by the ad owner
        "seller_#{conv.seller_id}"
      else
        # Current seller is the buyer, group by the ad owner
        "seller_#{conv.seller_id}"
      end
    end
    
    conversations_data = grouped_conversations.map do |participant_key, conversations|
      # Get the most recent conversation for this participant
      most_recent_conversation = conversations.max_by(&:updated_at)
      last_message = most_recent_conversation.messages.last

      {
        id: most_recent_conversation.id,
        seller_id: most_recent_conversation.seller_id,
        buyer_id: most_recent_conversation.buyer_id,
        inquirer_seller_id: most_recent_conversation.inquirer_seller_id,
        created_at: most_recent_conversation.created_at,
        updated_at: most_recent_conversation.updated_at,
        admin: most_recent_conversation.admin,
        buyer: most_recent_conversation.buyer,
        seller: most_recent_conversation.seller,
        inquirer_seller: most_recent_conversation.inquirer_seller,
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
    @conversation = Conversation.active_participants
                                .find_by(id: params[:id], seller_id: @current_seller.id)
    
    if @conversation
      # Get all conversations with the same buyer
      all_conversations_with_buyer = Conversation.where(
        seller_id: @current_seller.id,
        buyer_id: @conversation.buyer_id
      ).active_participants
      
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
    # Prevent sellers from messaging their own ads
    if params[:seller_id].to_i == @current_seller.id && params[:buyer_id].blank?
      render json: { error: 'You cannot message your own ads' }, status: :unprocessable_entity
      return
    end

    # Determine the conversation structure based on who is messaging
    if params[:seller_id].to_i == @current_seller.id
      # Current seller owns the ad - they are responding to a buyer/inquirer
      seller_id = @current_seller.id
      buyer_id = params[:buyer_id]
      inquirer_seller_id = nil
    else
      # Current seller is inquiring about someone else's ad
      seller_id = params[:seller_id]  # Ad owner
      buyer_id = nil  # No buyer involved
      inquirer_seller_id = @current_seller.id  # Current seller is the inquirer
    end

    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      seller_id: seller_id,
      buyer_id: buyer_id,
      inquirer_seller_id: inquirer_seller_id,
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
    @conversation = Conversation.active_participants
                                .find_by(id: params[:id], seller_id: @current_seller.id)
    
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
                                .active_participants
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                                .where(read_at: nil)
                                .count
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    # Count conversations with unread messages
    conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }
    
    render json: { 
      unread_counts: unread_counts,
      conversations_with_unread: conversations_with_unread
    }
  end

  # GET /seller/conversations/unread_count
  def unread_count
    # Get all conversations for the current seller
    conversations = Conversation.where(seller_id: @current_seller.id)
                                .active_participants
    
    # Count unread messages (messages not sent by seller and not read)
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Buyer', 'Admin', 'SalesUser'] })
                               .where(messages: { read_at: nil })
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