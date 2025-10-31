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
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def online_status
    participant_ids = params[:participant_ids] || []
    online_status = {}
    
    Rails.logger.info "Checking online status for participants: #{participant_ids}"
    
    participant_ids.each do |participant_id|
      # Parse participant ID format: "buyer_123", "seller_456", "admin_789"
      parts = participant_id.split('_')
      next if parts.length != 2
      
      user_type = parts[0]
      user_id = parts[1].to_i
      
      # Check if user is online using Rails cache
      cache_key = "online_user_#{user_type}_#{user_id}"
      is_online = Rails.cache.exist?(cache_key)
      
      Rails.logger.info "User #{participant_id}: cache_key=#{cache_key}, online=#{is_online}"
      online_status[participant_id] = is_online
    end
    
    Rails.logger.info "Online status result: #{online_status}"
    render json: { online_status: online_status }, status: :ok
  end

  private

  def authenticate_user
    # Extract token from Authorization header
    token = request.headers['Authorization']&.split(' ')&.last
    
    unless token
      Rails.logger.warn "ConversationsController: No token provided in Authorization header"
      render json: { error: 'Not Authorized - No token provided' }, status: :unauthorized
      return
    end
    
    begin
      # Decode token to get user info
      result = JsonWebToken.decode(token)
      
      # Check if decoding was successful
      unless result[:success]
        Rails.logger.warn "ConversationsController: Token decode failed - #{result[:error]}"
        render json: { error: result[:error] || 'Invalid token' }, status: :unauthorized
        return
      end
      
      # Extract the actual payload
      decoded = result[:payload]
      
      # Extract role
      role = (decoded[:role] || decoded['role'])&.downcase
      Rails.logger.info "ConversationsController: Authenticating user with role: #{role}"
      
      # Find the user based on role and extract appropriate ID
      @current_user = nil
      user_id = nil
      
      case role
      when 'seller'
        user_id = decoded[:seller_id] || decoded['seller_id']
        @current_user = Seller.find_by(id: user_id) if user_id
        Rails.logger.info "ConversationsController: Found seller #{user_id}" if @current_user
        
      when 'buyer'
        user_id = decoded[:buyer_id] || decoded['buyer_id'] || decoded[:user_id] || decoded['user_id']
        @current_user = Buyer.find_by(id: user_id) if user_id
        Rails.logger.info "ConversationsController: Found buyer #{user_id}" if @current_user
        
      when 'admin'
        # Admin tokens use user_id, not admin_id (same as buyers)
        user_id = decoded[:user_id] || decoded['user_id'] || decoded[:admin_id] || decoded['admin_id']
        @current_user = Admin.find_by(id: user_id) if user_id
        Rails.logger.info "ConversationsController: Found admin #{user_id}" if @current_user
        
      when 'sales', 'salesuser'
        # Sales tokens use user_id, not sales_id (same as buyers/admins)
        user_id = decoded[:user_id] || decoded['user_id'] || decoded[:sales_id] || decoded['sales_id']
        @current_user = SalesUser.find_by(id: user_id) if user_id
        Rails.logger.info "ConversationsController: Found sales user #{user_id}" if @current_user
        
      else
        Rails.logger.warn "ConversationsController: Invalid user role: #{role}"
        render json: { error: "Invalid user role: #{role}" }, status: :unauthorized
        return
      end
      
      unless @current_user
        Rails.logger.warn "ConversationsController: User not found for role: #{role}, id: #{user_id}"
        Rails.logger.warn "ConversationsController: Decoded token keys: #{decoded.keys}"
        render json: { error: 'User not found' }, status: :unauthorized
      end
      
    rescue JWT::DecodeError => e
      Rails.logger.warn "ConversationsController: JWT decode error - #{e.message}"
      render json: { error: 'Invalid token format' }, status: :unauthorized
    rescue => e
      Rails.logger.error "ConversationsController: Authentication error: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      render json: { error: 'Authentication failed' }, status: :unauthorized
    end
  end


  def set_conversation
    @conversation = case @current_user.class.name
                   when 'Buyer'
                     find_buyer_conversation
                   when 'Seller'
                     find_seller_conversation
                   when 'Admin', 'SalesUser'
                     find_admin_conversation
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

    # If seller_id is not provided but ad_id is, get seller_id from the ad
    if params[:seller_id].blank? && params[:ad_id].present?
      ad = Ad.find(params[:ad_id])
      seller_id = ad.seller_id
    end

    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      buyer_id: buyer_id,
      seller_id: seller_id,
      ad_id: params[:ad_id]
    ) do |conv|
      conv.admin_id = params[:admin_id] if params[:admin_id].present?
    end

    # Ensure the conversation is saved and valid
    unless @conversation.persisted?
      Rails.logger.error "Conversation validation errors: #{@conversation.errors.full_messages}"
      render json: { error: 'Failed to create conversation', details: @conversation.errors.full_messages }, status: :unprocessable_entity
      return
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
      elsif conv.inquirer_seller_id == @current_user.id
        # Current seller is the inquirer, group by the ad owner
        "seller_#{conv.seller_id}"
      else
        # Current seller is the buyer, group by the ad owner
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
    Rails.logger.info "Seller conversation creation - Current user: #{@current_user.id}, Params: #{params.inspect}"
    
    # Prevent sellers from messaging their own ads
    if params[:seller_id].to_i == @current_user.id && params[:buyer_id].blank?
      Rails.logger.warn "Seller #{@current_user.id} trying to message their own ad"
      render json: { error: 'You cannot message your own ads' }, status: :unprocessable_entity
      return
    end

    # Additional validation: check if ad belongs to current user (prevent self-messaging via ad_id)
    if params[:ad_id].present?
      ad = Ad.find_by(id: params[:ad_id])
      if ad && ad.seller_id == @current_user.id && (params[:seller_id].blank? || params[:seller_id].to_i == @current_user.id)
        Rails.logger.warn "Seller #{@current_user.id} trying to message themselves via ad_id"
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
      Rails.logger.info "Seller-to-buyer conversation: seller_id=#{seller_id}, buyer_id=#{buyer_id}"
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
      Rails.logger.info "Seller-to-seller conversation: seller_id=#{seller_id}, inquirer_seller_id=#{inquirer_seller_id}"
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

    # Ensure the conversation is saved and valid
    unless @conversation.persisted?
      Rails.logger.error "Conversation validation errors: #{@conversation.errors.full_messages}"
      render json: { error: 'Failed to create conversation', details: @conversation.errors.full_messages }, status: :unprocessable_entity
      return
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
    # If seller_id is not provided but ad_id is, get seller_id from the ad
    seller_id = params[:seller_id]
    if params[:seller_id].blank? && params[:ad_id].present?
      ad = Ad.find(params[:ad_id])
      seller_id = ad.seller_id
    end

    # Find existing conversation or create new one
    @conversation = Conversation.find_or_create_by(
      admin_id: @current_user.id,
      seller_id: seller_id,
      buyer_id: params[:buyer_id],
      ad_id: params[:ad_id]
    )

    # Ensure the conversation is saved and valid
    unless @conversation.persisted?
      Rails.logger.error "Conversation validation errors: #{@conversation.errors.full_messages}"
      render json: { error: 'Failed to create conversation', details: @conversation.errors.full_messages }, status: :unprocessable_entity
      return
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
                                .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
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

  def fetch_seller_unread_counts
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    )
    
    unread_counts = conversations.map do |conversation|
      # For seller-to-seller conversations, count messages not sent by current user
      # For regular conversations, count messages from buyers, admins, and sales users
      if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
        # Seller-to-seller conversation: count messages not sent by current user
        unread_count = conversation.messages
                                  .where.not(sender_id: @current_user.id)
                                  .where(read_at: nil)
                                  .count
      else
        # Regular conversation: count messages from buyers, admins, and sales users
        unread_count = conversation.messages
                                  .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                                  .where(read_at: nil)
                                  .count
      end
      
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

  def fetch_admin_unread_counts
    conversations = Conversation.where(admin_id: @current_user.id)
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer'])
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

  def fetch_buyer_unread_count
    conversations = Conversation.where(buyer_id: @current_user.id)
    
    unread_count = conversations.joins(:messages)
                               .where(messages: { sender_type: ['Seller', 'Admin', 'SalesUser'] })
                               .where(messages: { read_at: nil })
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
                                  .where(read_at: nil)
                                  .count
      else
        # Regular conversation: count messages from buyers, admins, and sales users
        unread_count = conversation.messages
                                  .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                                  .where(read_at: nil)
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
