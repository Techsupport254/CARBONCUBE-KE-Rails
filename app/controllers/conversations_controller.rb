class ConversationsController < ApplicationController
  before_action :authenticate_user
  before_action :set_conversation, only: [:show]

  def index
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_conversations
    when 'Seller'
      fetch_seller_conversations
    when 'Admin', 'SalesUser'
      fetch_admin_conversations
    when 'Rider'
      render json: { conversations: [] }, status: :ok  # Riders don't have conversations
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def show
    case @current_user.class.name
    when 'Buyer'
      render_buyer_conversation
    when 'Seller'
      render_seller_conversation
    when 'Admin', 'SalesUser'
      render_admin_conversation
    when 'Rider'
      render json: { error: 'Riders do not have access to conversations' }, status: :forbidden
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def create
    case @current_user.class.name
    when 'Buyer'
      create_buyer_conversation
    when 'Seller'
      create_seller_conversation
    when 'Admin', 'SalesUser'
      create_admin_conversation
    when 'Rider'
      render json: { error: 'Riders cannot create conversations' }, status: :forbidden
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def unread_counts
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_unread_counts
    when 'Seller'
      fetch_seller_unread_counts
    when 'Admin', 'SalesUser'
      fetch_admin_unread_counts
    when 'Rider'
      render json: { unread_counts: {} }, status: :ok  # Riders don't have conversations
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def unread_count
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_unread_count
    when 'Seller'
      fetch_seller_unread_count
    when 'Admin', 'SalesUser'
      fetch_admin_unread_count
    when 'Rider'
      render json: { unread_count: 0 }, status: :ok  # Riders don't have conversations
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_user
    # Try authenticating as different user types
    @current_user = authenticate_seller || authenticate_buyer || authenticate_admin || authenticate_sales || authenticate_rider
    
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

  def authenticate_sales
    SalesAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_rider
    RiderAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def set_conversation
    @conversation = case @current_user.class.name
                   when 'Buyer'
                     find_buyer_conversation
                   when 'Seller'
                     find_seller_conversation
                   when 'Admin', 'SalesUser'
                     find_admin_conversation
                   when 'Rider'
                     nil  # Riders don't have conversations
                   end

    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
    end
  end

  def find_buyer_conversation
    Conversation.find_by(id: params[:id], buyer_id: @current_user.id)
  end

  def find_seller_conversation
    Conversation.where(
      id: params[:id]
    ).where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    ).first
  end

  def find_admin_conversation
    Conversation.find_by(id: params[:id])
  end

  # Buyer conversation methods
  def fetch_buyer_conversations
    # Implementation from buyer conversations controller
    @conversations = Conversation.where(buyer_id: @current_user.id)
                                .includes(:admin, :buyer, :seller, :ad, :messages)
                                .order(updated_at: :desc)
    render json: @conversations, each_serializer: ConversationSerializer
  end

  def render_buyer_conversation
    render json: @conversation, serializer: ConversationSerializer
  end

  def create_buyer_conversation
    # Determine buyer_id and seller_id based on current user type
    buyer_id = @current_user.id
    seller_id = params[:seller_id]

    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      buyer_id: buyer_id,
      seller_id: seller_id,
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
      sender: @current_user,
      ad_id: @conversation.ad_id
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

  # Seller conversation methods
  def fetch_seller_conversations
    # Implementation from seller conversations controller
    @conversations = Conversation.where(
      "(seller_id = ? OR buyer_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id,
      @current_user.id
    ).includes(:admin, :buyer, :seller, :inquirer_seller, :ad, :messages)
     .order(updated_at: :desc)
    
    # Group and format as per seller controller logic
    grouped_conversations = @conversations.group_by do |conv|
      if conv.seller_id == @current_user.id
        if conv.buyer_id.present?
          "buyer_#{conv.buyer_id}"
        else
          "inquirer_seller_#{conv.inquirer_seller_id}"
        end
      elsif conv.inquirer_seller_id == @current_user.id
        "seller_#{conv.seller_id}"
      else
        "seller_#{conv.seller_id}"
      end
    end
    
    # Serialize each conversation group to include user associations
    serialized_groups = {}
    grouped_conversations.each do |key, conversations|
      serialized_groups[key] = conversations.map do |conv|
        ConversationSerializer.new(conv).as_json
      end
    end
    
    render json: serialized_groups
  end

  def render_seller_conversation
    render json: @conversation, serializer: ConversationSerializer
  end

  def create_seller_conversation
    # Prevent sellers from messaging their own ads
    if params[:seller_id].to_i == @current_user.id && params[:buyer_id].blank?
      render json: { error: 'You cannot message your own ads' }, status: :unprocessable_entity
      return
    end

    # Additional validation: check if ad belongs to current user (prevent self-messaging via ad_id)
    if params[:ad_id].present?
      ad = Ad.find_by(id: params[:ad_id])
      if ad && ad.seller_id == @current_user.id && (params[:seller_id].blank? || params[:seller_id].to_i == @current_user.id)
        render json: { error: 'You cannot message yourself about your own ads' }, status: :unprocessable_entity
        return
      end
    end

    # Determine the conversation structure based on who is messaging
    if params[:seller_id].to_i == @current_user.id
      # Current seller owns the ad - they are responding to a buyer/inquirer
      seller_id = @current_user.id
      buyer_id = params[:buyer_id]
      inquirer_seller_id = nil
    else
      # Current seller is inquiring about someone else's ad
      seller_id = params[:seller_id]  # Ad owner
      buyer_id = nil  # No buyer involved
      inquirer_seller_id = @current_user.id  # Current seller is the inquirer
      
      # If seller_id is not provided, derive it from the ad
      if seller_id.blank? && params[:ad_id].present?
        ad = Ad.find_by(id: params[:ad_id])
        seller_id = ad.seller_id if ad
      end
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
      sender: @current_user,
      ad_id: @conversation.ad_id
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

  # Admin conversation methods
  def fetch_admin_conversations
    @conversations = Conversation.all.includes(:admin, :buyer, :seller, :ad, :messages)
                                    .order(updated_at: :desc)
    render json: @conversations, each_serializer: ConversationSerializer
  end

  def render_admin_conversation
    render json: @conversation, serializer: ConversationSerializer
  end

  def create_admin_conversation
    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      admin_id: @current_user.id,
      seller_id: params[:seller_id],
      buyer_id: params[:buyer_id],
      ad_id: params[:ad_id]
    ) do |conv|
      # If seller_id is not provided but ad_id is, get seller_id from the ad
      if params[:seller_id].blank? && params[:ad_id].present?
        ad = Ad.find(params[:ad_id])
        conv.seller_id = ad.seller_id
      end
    end

    # Create the message
    message = @conversation.messages.create!(
      content: params[:content],
      sender: @current_user,
      ad_id: @conversation.ad_id
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

  # Unread counts methods
  def fetch_buyer_unread_counts
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

  def fetch_seller_unread_counts
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    )
    
    unread_counts = conversations.map do |conversation|
      # For seller-to-seller conversations, count messages not sent by current user
      # For regular conversations, count messages from buyers and admins
      if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
        # Seller-to-seller conversation: count messages not sent by current user
        unread_count = conversation.messages
                                  .where.not(sender_id: @current_user.id)
                                  .where(status: [nil, Message::STATUS_SENT])
                                  .count
      else
        # Regular conversation: count messages from buyers and admins
        unread_count = conversation.messages
                                  .where(sender_type: ['Buyer', 'Admin'])
                                  .where(status: [nil, Message::STATUS_SENT])
                                  .count
      end
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    render json: { unread_counts: unread_counts }
  end

  def fetch_admin_unread_counts
    conversations = Conversation.where(admin_id: @current_user.id)
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer'])
                                .where(status: [nil, Message::STATUS_SENT])
                                .count
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    render json: { unread_counts: unread_counts }
  end

  def fetch_buyer_unread_count
    conversations = Conversation.where(buyer_id: @current_user.id)
    
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Seller', 'Admin'] })
                               .where(messages: { status: [nil, Message::STATUS_SENT] })
                               .count
    
    render json: { count: unread_count }
  end

  def fetch_seller_unread_count
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    )
    
    # Calculate total unread count handling seller-to-seller conversations
    total_unread = 0
    conversations.each do |conversation|
      if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
        # Seller-to-seller conversation: count messages not sent by current user
        unread_count = conversation.messages
                                  .where.not(sender_id: @current_user.id)
                                  .where(status: [nil, Message::STATUS_SENT])
                                  .count
      else
        # Regular conversation: count messages from buyers and admins
        unread_count = conversation.messages
                                  .where(sender_type: ['Buyer', 'Admin'])
                                  .where(status: [nil, Message::STATUS_SENT])
                                  .count
      end
      total_unread += unread_count
    end
    
    render json: { count: total_unread }
  end

  def fetch_admin_unread_count
    conversations = Conversation.where(admin_id: @current_user.id)
    
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Seller', 'Buyer'] })
                               .where(messages: { status: [nil, Message::STATUS_SENT] })
                               .count
    
    render json: { count: unread_count }
  end
end
