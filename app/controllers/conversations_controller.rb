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
    Rails.logger.info "ConversationsController#create called with params: #{params.inspect}"
    Rails.logger.info "ConversationsController#create current_user: #{@current_user&.class&.name}, id: #{@current_user&.id}"
    
    unless @current_user
      Rails.logger.error "ConversationsController#create: No current_user set"
      render json: { error: 'Authentication required' }, status: :unauthorized
      return
    end
    
    case @current_user.class.name
    when 'Buyer'
      create_buyer_conversation
    when 'Seller'
      create_seller_conversation
    when 'Admin', 'SalesUser'
      create_admin_conversation
    else
      Rails.logger.error "ConversationsController#create: Invalid user type: #{@current_user.class.name}"
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def unread_counts
    Rails.logger.info "ConversationsController#unread_counts: Current user class: #{@current_user.class.name}, ID: #{@current_user.id}"
    
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_unread_counts
    when 'Seller'
      fetch_seller_unread_counts
    when 'Admin', 'SalesUser'
      fetch_admin_unread_counts
    else
      Rails.logger.error "ConversationsController#unread_counts: Invalid user type: #{@current_user.class.name}"
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
      user_id = parts[1]
      
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

  def fix_conversations_sequence
    begin
      max_id = Conversation.maximum(:id) || 0
      sequence_name = ActiveRecord::Base.connection.execute(
        "SELECT pg_get_serial_sequence('conversations', 'id') as seq_name"
      ).first['seq_name']
      
      if sequence_name
        # Set sequence to max_id + 1 to ensure next ID is available
        ActiveRecord::Base.connection.execute(
          "SELECT setval('#{sequence_name}', #{max_id + 1}, false)"
        )
        Rails.logger.info "Fixed conversations_id_seq to #{max_id + 1} (max ID was #{max_id})"
      else
        Rails.logger.warn "Could not find sequence for conversations.id"
      end
    rescue => e
      Rails.logger.error "Failed to fix conversations sequence: #{e.message}"
    end
  end

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
    # For Sales users, allow access to any conversation
    # For Admins, allow access to any conversation (they can see all)
    Conversation.active_participants.find_by(id: params[:id])
  end

  # Buyer conversation methods
  def fetch_buyer_conversations
    # Implementation from buyer conversations controller
    # Only return conversations that have at least one message
    @conversations = Conversation.where("conversations.buyer_id = ?", @current_user.id)
                                .active_participants
                                .includes(:admin, :buyer, :seller, :ad, :messages)
                                .joins(:messages)
                                .distinct
                                .order("conversations.updated_at DESC")
    render json: @conversations, each_serializer: ConversationSerializer
  end

  def render_buyer_conversation
    render json: @conversation, serializer: ConversationSerializer
  end

  def create_buyer_conversation
    Rails.logger.info "create_buyer_conversation called with params: #{params.inspect}"
    Rails.logger.info "Current user: #{@current_user.class.name}, id: #{@current_user.id}, type: #{@current_user.id.class.name}"
    
    # Determine buyer_id and seller_id based on current user type
    buyer_id = @current_user.id
    seller_id = params[:seller_id]

    # If seller_id is not provided but ad_id is, get seller_id from the ad
    if params[:seller_id].blank? && params[:ad_id].present?
      ad = Ad.find_by(id: params[:ad_id])
      if ad
        seller_id = ad.seller_id
        Rails.logger.info "Got seller_id from ad: #{seller_id}, type: #{seller_id.class.name}"
      else
        Rails.logger.error "Ad not found: #{params[:ad_id]}"
        render json: { error: 'Ad not found' }, status: :not_found
        return
      end
    end

    # Ensure seller_id is present
    unless seller_id.present?
      Rails.logger.error "seller_id is missing - params: #{params.inspect}"
      render json: { error: 'seller_id is required' }, status: :unprocessable_entity
      return
    end

    Rails.logger.info "Looking for conversation with buyer_id: #{buyer_id} (#{buyer_id.class.name}), seller_id: #{seller_id} (#{seller_id.class.name}), ad_id: #{params[:ad_id]}"

    # Find existing conversation or create new one
    # Handle race conditions where multiple requests try to create the same conversation
    begin
      # Use the model method that handles race conditions properly
      @conversation = Conversation.find_or_create_conversation!(
        buyer_id: buyer_id,
        seller_id: seller_id,
        ad_id: params[:ad_id],
        inquirer_seller_id: nil,
        admin_id: params[:admin_id].presence
      )
      Rails.logger.info "Found or created conversation: #{@conversation.id}"
    rescue => e
      Rails.logger.error "Error in conversation creation: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      render json: { error: "Failed to create conversation: #{e.message}" }, status: :unprocessable_entity
      return
    end
    
    # Check if conversation was actually created
    unless @conversation
      Rails.logger.error "Conversation was nil after find_or_create_conversation!"
      render json: { error: 'Failed to create conversation due to race condition' }, status: :unprocessable_entity
      return
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
    # Only return conversations that have at least one message
    @conversations = Conversation.where(
      "(conversations.seller_id = ? OR conversations.buyer_id = ? OR conversations.inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id,
      @current_user.id
    ).active_participants
     .includes(:admin, :buyer, :seller, :inquirer_seller, :ad, :messages)
     .joins(:messages)
     .distinct
     .order("conversations.updated_at DESC")
    
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
    if params[:seller_id].present? && params[:seller_id] == @current_user.id.to_s && params[:buyer_id].blank?
      Rails.logger.warn "Seller #{@current_user.id} trying to message their own ad"
      render json: { error: 'You cannot message your own ads' }, status: :unprocessable_entity
      return
    end

    # Additional validation: check if ad belongs to current user (prevent self-messaging via ad_id)
    if params[:ad_id].present?
      ad = Ad.find_by(id: params[:ad_id])
      if ad && ad.seller_id == @current_user.id && (params[:seller_id].blank? || params[:seller_id] == @current_user.id.to_s)
        Rails.logger.warn "Seller #{@current_user.id} trying to message themselves via ad_id"
        render json: { error: 'You cannot message yourself about your own ads' }, status: :unprocessable_entity
        return
      end
    end

    # Determine the conversation structure based on who is messaging
    if params[:seller_id].present? && params[:seller_id] == @current_user.id.to_s
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
    # Handle race conditions where multiple requests try to create the same conversation
    begin
      # Use the model method that handles race conditions properly
      @conversation = Conversation.find_or_create_conversation!(
        seller_id: seller_id,
        buyer_id: buyer_id,
        inquirer_seller_id: inquirer_seller_id,
        ad_id: params[:ad_id],
        admin_id: params[:admin_id].presence
      )
      Rails.logger.info "Found or created conversation: #{@conversation.id}"
    rescue => e
      Rails.logger.error "Error in conversation creation: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      render json: { error: "Failed to create conversation: #{e.message}" }, status: :unprocessable_entity
      return
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
    # For Sales users, show all conversations (they can see all conversations like admins)
    # For Admins, show conversations where they are the admin_id
    if @current_user.is_a?(SalesUser)
      # Sales users can see all conversations
      @conversations = Conversation.active_participants
                                      .includes(:admin, :buyer, :seller, :ad, :messages)
                                      .joins(:messages)
                                      .distinct
                                      .order("conversations.updated_at DESC")
    else
      # Admins see conversations where they are assigned (admin_id)
      @conversations = Conversation.where(admin_id: @current_user.id)
                                      .active_participants
                                      .includes(:admin, :buyer, :seller, :ad, :messages)
                                      .joins(:messages)
                                      .distinct
                                      .order("conversations.updated_at DESC")
    end
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
    # Handle race conditions where multiple requests try to create the same conversation
    begin
      # Use the model method that handles race conditions properly
      @conversation = Conversation.find_or_create_conversation!(
        admin_id: @current_user.id,
        seller_id: seller_id,
        buyer_id: params[:buyer_id],
        inquirer_seller_id: nil,
        ad_id: params[:ad_id]
      )
      Rails.logger.info "Found or created conversation: #{@conversation.id}"
    rescue => e
      Rails.logger.error "Error in conversation creation: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      render json: { error: "Failed to create conversation: #{e.message}" }, status: :unprocessable_entity
      return
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

  # Unread counts methods
  def fetch_buyer_unread_counts
    conversations = Conversation.where(buyer_id: @current_user.id)
                                .active_participants
    
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
    Rails.logger.info "ConversationsController#fetch_seller_unread_counts: Current user: #{@current_user.class.name} #{@current_user.id}"
    
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    ).active_participants
    
    Rails.logger.info "ConversationsController#fetch_seller_unread_counts: Found #{conversations.count} conversations"
    
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
      
      Rails.logger.info "ConversationsController#fetch_seller_unread_counts: Conversation #{conversation.id} has #{unread_count} unread messages"
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    # Count conversations with unread messages
    conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }
    
    total_unread = unread_counts.sum { |item| item[:unread_count] || 0 }
    Rails.logger.info "ConversationsController#fetch_seller_unread_counts: Total unread: #{total_unread}, Conversations with unread: #{conversations_with_unread}"
    
    render json: { 
      unread_counts: unread_counts,
      conversations_with_unread: conversations_with_unread
    }
  end

  def fetch_admin_unread_counts
    Rails.logger.info "ConversationsController#fetch_admin_unread_counts: Current user: #{@current_user.class.name} #{@current_user.id}"
    
    # For Sales users, show all conversations (they can see all conversations like admins)
    # For Admins, show conversations where they are the admin_id
    if @current_user.is_a?(SalesUser)
      conversations = Conversation.active_participants
      Rails.logger.info "ConversationsController#fetch_admin_unread_counts: Sales user - showing all active conversations: #{conversations.count}"
    else
      conversations = Conversation.where(admin_id: @current_user.id)
                                  .active_participants
      Rails.logger.info "ConversationsController#fetch_admin_unread_counts: Admin - Found #{conversations.count} conversations with admin_id=#{@current_user.id}"
      
      # If no conversations found with admin_id, check if there are any conversations at all for this user
      if conversations.count == 0
        all_conversations = Conversation.where(admin_id: @current_user.id)
        Rails.logger.info "ConversationsController#fetch_admin_unread_counts: Total conversations (including inactive): #{all_conversations.count}"
      end
    end
    
    unread_counts = conversations.map do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      
      Rails.logger.info "ConversationsController#fetch_admin_unread_counts: Conversation #{conversation.id} has #{unread_count} unread messages"
      
      {
        conversation_id: conversation.id,
        unread_count: unread_count
      }
    end
    
    # Count conversations with unread messages
    conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }
    
    total_unread = unread_counts.sum { |item| item[:unread_count] || 0 }
    Rails.logger.info "ConversationsController#fetch_admin_unread_counts: Total unread: #{total_unread}, Conversations with unread: #{conversations_with_unread}"
    
    render json: { 
      unread_counts: unread_counts,
      conversations_with_unread: conversations_with_unread
    }
  end

  def fetch_buyer_unread_count
    conversations = Conversation.where(buyer_id: @current_user.id)
                                .active_participants
    
    # Calculate total unread count by iterating through conversations
    # This avoids duplicate counting issues with joins
    total_unread = 0
    conversations.each do |conversation|
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    render json: { count: total_unread }
  end

  def fetch_seller_unread_count
    conversations = Conversation.where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    ).active_participants
    
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
    # For Sales users, show all conversations (they can see all conversations like admins)
    # For Admins, show conversations where they are the admin_id
    if @current_user.is_a?(SalesUser)
      conversations = Conversation.active_participants
    else
      # For Admin, conversations are stored with admin_id
      conversations = Conversation.where(admin_id: @current_user.id)
                                  .active_participants
    end
    
    # Calculate total unread count by iterating through conversations
    # This avoids duplicate counting issues with joins
    total_unread = 0
    conversations.each do |conversation|
      # Count messages from sellers, buyers, and purchasers (not from admin/sales users)
      unread_count = conversation.messages
                                .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                                .where(read_at: nil)
                                .count
      total_unread += unread_count
    end
    
    render json: { count: total_unread }
  end
end
