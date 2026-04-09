class ConversationsController < ApplicationController
  before_action :authenticate_user
  before_action :set_conversation, only: [:show]

  def index
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_conversations
    when 'Seller'
      fetch_seller_conversations
    when 'Admin', 'SalesUser', 'MarketingUser'
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
    when 'Admin', 'SalesUser', 'MarketingUser'
      render_admin_conversation
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def create
    
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
    when 'Admin', 'SalesUser', 'MarketingUser'
      create_admin_conversation
    else
      Rails.logger.error "ConversationsController#create: Invalid user type: #{@current_user.class.name}"
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def unread_counts
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_unread_counts
    when 'Seller'
      fetch_seller_unread_counts
    when 'Admin', 'SalesUser', 'MarketingUser'
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
    when 'Admin', 'SalesUser', 'MarketingUser'
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

  def mark_read
    @conversation = case @current_user.class.name
                   when 'Buyer'
                     find_buyer_conversation
                   when 'Seller'
                     find_seller_conversation
                   when 'Admin', 'SalesUser', 'MarketingUser'
                     find_admin_conversation
                   end

    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
      return
    end

    unread_messages = related_conversations_for_mark_read.flat_map do |conversation|
      # For staff roles, only mark as read if they are the assigned admin/salesperson
      is_staff = ['Admin', 'SalesUser', 'MarketingUser'].include?(@current_user.class.name)
      if is_staff && conversation.admin_id != @current_user.id
        next []
      end

      conversation.messages.unread.where.not(sender: @current_user).to_a
    end
    
    processed_count = 0
    unread_messages.each do |message|
      message.mark_as_read!
      # We could broadcast here, but mark_as_read! might already do it or we can do it manually
      # messages_controller.rb has broadcast_read_receipt(message)
      # But since we're in ConversationsController, we'll just mark them.
      processed_count += 1
    end

    # Update unread counts once for the conversation
    if processed_count > 0
      begin
        UpdateUnreadCountsJob.perform_now(@conversation.id, unread_messages.last.id)
      rescue => e
        Rails.logger.warn "Failed to update unread counts: #{e.message}"
        UpdateUnreadCountsJob.perform_later(@conversation.id, unread_messages.last.id)
      end
    end

    render json: { 
      success: true, 
      processed_count: processed_count,
      message: "Marked #{processed_count} messages as read" 
    }
  end

  def ping_client
    # Only allow admins and sales users to ping sellers
    unless @current_user.is_a?(Admin) || @current_user.is_a?(SalesUser)
      render json: { error: 'Only admins and sales users can ping sellers' }, status: :forbidden
      return
    end

    # Find conversation manually (not using before_action to avoid Rails 7.1 callback validation issue)
    conversation = find_admin_conversation

    unless conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
      return
    end

    # Only ping sellers, not buyers
    # Priority: seller > inquirer_seller
    seller = conversation.seller || conversation.inquirer_seller

    unless seller
      render json: { 
        error: 'No seller found in this conversation',
        error_type: 'no_seller'
      }, status: :unprocessable_entity
      return
    end

    # Count unread messages for the seller (messages not sent by the seller)
    # Use read_at: nil to match the same logic used in unread_counts endpoint
    unread_count = conversation.messages
      .where.not(sender: seller)
      .where(read_at: nil)
      .count

    if unread_count == 0
      render json: { 
        error: 'No unread messages to notify about',
        error_type: 'no_unread_messages'
      }, status: :unprocessable_entity
      return
    end

    # Check if seller has a phone number
    unless seller.phone_number.present?
      render json: { 
        error: 'Seller does not have a phone number registered. Please ask the seller to add their phone number to their profile.',
        error_type: 'no_phone_number'
      }, status: :unprocessable_entity
      return
    end

    # Validate phone number format (basic check)
    phone_number = seller.phone_number.to_s.gsub(/\D/, '')
    if phone_number.length < 7
      render json: {
        error: 'Seller phone number format is invalid. Please ask the seller to update their phone number.',
        error_type: 'invalid_phone_format'
      }, status: :unprocessable_entity
      return
    end

    # Check if WhatsApp notifications are enabled
    unless ENV['WHATSAPP_NOTIFICATIONS_ENABLED'] == 'true'
      # In development, return success with a dev message
      if Rails.env.development?
        render json: { 
          success: true, 
          message: 'WhatsApp notifications are disabled (development mode)',
          unread_count: unread_count,
          development_mode: true
        }, status: :ok
        return
      else
        render json: { 
          error: 'WhatsApp notifications are not enabled',
          message: 'WhatsApp notifications are currently disabled on this server.',
          error_type: 'notifications_disabled'
        }, status: :service_unavailable
        return
      end
    end

    # Build notification message
    sender_name = @current_user.is_a?(Admin) ? 'Carbon Cube Support' : 'Carbon Cube Sales Team'
    
    # Message preview for template
    last_message = conversation.messages
      .where.not(sender: seller)
      .order(created_at: :desc)
      .first
    
    message_preview = last_message&.content&.truncate(100) || "You have #{unread_count} unread message#{unread_count > 1 ? 's' : ''}"

    # Send WhatsApp notification using the new professional UTILITY template
    # Template: ping_seller_message_v1 (Utility)
    # Variable 1: Seller Name
    # Variable 2: Unread Count
    # Variable 3: Sender Name
    # Variable 4: Message Preview
    # Button Variable 1: Conversation ID
    
    result = WhatsAppCloudService.send_template(
      seller.phone_number,
      'ping_seller_message_v1',
      'en',
      [
        {
          type: 'body',
          parameters: [
            { type: 'text', text: seller.fullname || 'Seller' },
            { type: 'text', text: unread_count.to_s },
            { type: 'text', text: sender_name },
            { type: 'text', text: message_preview }
          ]
        },
        {
          type: 'button',
          sub_type: 'url',
          index: 0,
          parameters: [
            { type: 'text', text: conversation.id.to_s }
          ]
        }
      ]
    )

    if result[:success]
      render json: { 
        success: true, 
        message: 'Seller notified via professional WhatsApp template',
        unread_count: unread_count
      }, status: :ok
    else
      # Handle different error types
      error_type = result[:error_type] || 'unknown'
      error_message = result[:error] || 'Failed to send WhatsApp template notification'
      
      # If service is unavailable, return a graceful response
      if ['service_unavailable', 'connection_error', 'timeout'].include?(error_type)
        render json: { 
          success: true,
          message: 'Notification attempt logged. WhatsApp service is temporarily unavailable.',
          unread_count: unread_count,
          warning: true
        }, status: :ok
        return
      end
      
      render json: { 
        error: error_message,
        error_type: error_type
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error pinging seller: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'An error occurred while pinging the seller', details: e.message }, status: :internal_server_error
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
      
      # Find the user based on role and extract appropriate ID
      @current_user = nil
      user_id = nil
      
      case role
      when 'seller'
        user_id = decoded[:seller_id] || decoded['seller_id']
        @current_user = Seller.find_by(id: user_id) if user_id
        
      when 'buyer'
        user_id = decoded[:buyer_id] || decoded['buyer_id'] || decoded[:user_id] || decoded['user_id']
        @current_user = Buyer.find_by(id: user_id) if user_id
        
      when 'admin'
        # Admin tokens use user_id, not admin_id (same as buyers)
        user_id = decoded[:user_id] || decoded['user_id'] || decoded[:admin_id] || decoded['admin_id']
        @current_user = Admin.find_by(id: user_id) if user_id
        
      when 'sales', 'salesuser'
        # Sales tokens use user_id, not sales_id (same as buyers/admins)
        user_id = decoded[:user_id] || decoded['user_id'] || decoded[:sales_id] || decoded['sales_id']
        @current_user = SalesUser.find_by(id: user_id) if user_id
        
      when 'marketing'
        # Marketing tokens use user_id (same as buyers/admins/sales)
        user_id = decoded[:user_id] || decoded['user_id'] || decoded[:marketing_id] || decoded['marketing_id']
        @current_user = MarketingUser.find_by(id: user_id) if user_id
        
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
                   when 'Admin', 'SalesUser', 'MarketingUser'
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

  def related_conversations_for_mark_read
    return [@conversation] unless @conversation

    case @current_user.class.name
    when 'Buyer'
      if @conversation.seller_id.present?
        Conversation.where(buyer_id: @current_user.id, seller_id: @conversation.seller_id).active_participants.to_a
      elsif @conversation.admin_id.present?
        Conversation.where(buyer_id: @current_user.id, admin_id: @conversation.admin_id).active_participants.to_a
      else
        [@conversation]
      end
    when 'Seller'
      if @conversation.seller_id == @current_user.id
        if @conversation.buyer_id.present?
          Conversation.where(seller_id: @current_user.id, buyer_id: @conversation.buyer_id).active_participants.to_a
        elsif @conversation.inquirer_seller_id.present?
          Conversation.where(seller_id: @current_user.id, inquirer_seller_id: @conversation.inquirer_seller_id).active_participants.to_a
        elsif @conversation.admin_id.present?
          Conversation.where(seller_id: @current_user.id, admin_id: @conversation.admin_id).active_participants.to_a
        else
          [@conversation]
        end
      elsif @conversation.inquirer_seller_id == @current_user.id && @conversation.seller_id.present?
        Conversation.where(seller_id: @conversation.seller_id, inquirer_seller_id: @current_user.id).active_participants.to_a
      elsif @conversation.buyer_id == @current_user.id && @conversation.seller_id.present?
        Conversation.where(buyer_id: @current_user.id, seller_id: @conversation.seller_id).active_participants.to_a
      else
        [@conversation]
      end
    when 'SalesUser', 'MarketingUser', 'Admin'
      Conversation.where(
        admin_id: @conversation.admin_id,
        buyer_id: @conversation.buyer_id,
        seller_id: @conversation.seller_id,
        inquirer_seller_id: @conversation.inquirer_seller_id
      ).active_participants.to_a
    else
      [@conversation]
    end
  end

  # Buyer conversation methods
  def fetch_buyer_conversations
    conversations = Conversation.where("conversations.buyer_id = ?", @current_user.id)
                                .active_participants
                                .includes(:admin, :buyer, :seller, :ad, :messages)
                                .joins(:messages)
                                .distinct
                                .order("conversations.updated_at DESC")

    grouped_conversations = conversations.group_by do |conversation|
      if conversation.admin_id.present? && conversation.seller_id.blank?
        "admin_#{conversation.admin_id}"
      else
        "seller_#{conversation.seller_id || 'unknown'}"
      end
    end

    render json: serialize_grouped_conversations(grouped_conversations)
  end

  def render_buyer_conversation
    render json: @conversation, serializer: ConversationSerializer
  end

  def create_buyer_conversation
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
      Rails.logger.error "seller_id is missing"
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
    conversations = Conversation.where(
      "(conversations.seller_id = ? OR conversations.buyer_id = ? OR conversations.inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id,
      @current_user.id
    ).active_participants
     .includes(:admin, :buyer, :seller, :inquirer_seller, :ad, :messages)
     .joins(:messages)
     .distinct
     .order("conversations.updated_at DESC")

    grouped_conversations = conversations.group_by do |conversation|
      seller_group_key_for(conversation)
    end

    render json: serialize_grouped_conversations(grouped_conversations)
  end

  def render_seller_conversation
    render json: @conversation, serializer: ConversationSerializer
  end

  def create_seller_conversation
    
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
      conversations = Conversation.active_participants
                                  .includes(:admin, :buyer, :seller, :inquirer_seller, :ad, :messages)
                                  .joins(:messages)
                                  .distinct
                                  .order("conversations.updated_at DESC")
    else
      # Admins see conversations where they are assigned (admin_id)
      conversations = Conversation.where(admin_id: @current_user.id)
                                  .active_participants
                                  .includes(:admin, :buyer, :seller, :inquirer_seller, :ad, :messages)
                                  .joins(:messages)
                                  .distinct
                                  .order("conversations.updated_at DESC")
    end

    grouped_conversations = conversations.group_by do |conversation|
      admin_group_key_for(conversation)
    end

    render json: serialize_grouped_conversations(grouped_conversations)
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

    grouped_conversations = conversations.group_by do |conversation|
      if conversation.admin_id.present? && conversation.seller_id.blank?
        "admin_#{conversation.admin_id}"
      else
        "seller_#{conversation.seller_id || 'unknown'}"
      end
    end

    unread_counts = grouped_conversations.values.map do |conversation_group|
      representative = representative_conversation_for(conversation_group)
      unread_count = conversation_group.sum do |conversation|
        buyer_unread_count_for(conversation)
      end

      {
        conversation_id: representative.id,
        unread_count: unread_count
      }
    end

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
    ).active_participants

    grouped_conversations = conversations.group_by do |conversation|
      seller_group_key_for(conversation)
    end

    unread_counts = grouped_conversations.values.map do |conversation_group|
      representative = representative_conversation_for(conversation_group)
      unread_count = conversation_group.sum do |conversation|
        seller_unread_count_for(conversation)
      end

      {
        conversation_id: representative.id,
        unread_count: unread_count
      }
    end

    conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }

    render json: { 
      unread_counts: unread_counts,
      conversations_with_unread: conversations_with_unread
    }
  end

  def fetch_admin_unread_counts
    # For Sales users, show all conversations (they can see all conversations like admins)
    # For Admins, show conversations where they are the admin_id
    if @current_user.is_a?(SalesUser)
      conversations = Conversation.active_participants
    else
      conversations = Conversation.where(admin_id: @current_user.id)
                                  .active_participants
    end

    grouped_conversations = conversations.group_by do |conversation|
      admin_group_key_for(conversation)
    end

    unread_counts = grouped_conversations.values.map do |conversation_group|
      representative = representative_conversation_for(conversation_group)
      unread_count = conversation_group.sum do |conversation|
        conversation.messages
                    .where(sender_type: ['Seller', 'Buyer', 'Purchaser'])
                    .where(read_at: nil)
                    .count
      end

      {
        conversation_id: representative.id,
        unread_count: unread_count
      }
    end

    conversations_with_unread = unread_counts.count { |item| item[:unread_count] > 0 }

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

  def seller_group_key_for(conversation)
    if conversation.seller_id == @current_user.id
      return "buyer_#{conversation.buyer_id}" if conversation.buyer_id.present?
      return "inquirer_seller_#{conversation.inquirer_seller_id}" if conversation.inquirer_seller_id.present?
      return "admin_#{conversation.admin_id}" if conversation.admin_id.present?
    elsif conversation.inquirer_seller_id == @current_user.id || conversation.buyer_id == @current_user.id
      return "seller_#{conversation.seller_id}" if conversation.seller_id.present?
    end

    "unknown_#{conversation.id}"
  end

  def admin_group_key_for(conversation)
    buyer_key = conversation.buyer_id.presence || 'none'
    seller_key = conversation.seller_id.presence || 'none'
    inquirer_key = conversation.inquirer_seller_id.presence || 'none'
    admin_key = conversation.admin_id.presence || 'none'

    "admin_thread_#{admin_key}_buyer_#{buyer_key}_seller_#{seller_key}_inquirer_#{inquirer_key}"
  end

  def representative_conversation_for(conversations)
    conversations.max_by do |conversation|
      last_message_time = conversation.messages.maximum(:created_at)
      last_message_time || conversation.updated_at
    end
  end

  def serialize_grouped_conversations(grouped_conversations)
    grouped_conversations.values.map do |conversation_group|
      representative = representative_conversation_for(conversation_group)
      serialized = ConversationSerializer.new(representative).as_json
      last_message = conversation_group.flat_map(&:messages).max_by(&:created_at)

      serialized.merge(
        id: representative.id,
        updated_at: (last_message&.created_at || representative.updated_at),
        last_message: serialized_last_message(last_message),
        last_message_time: last_message&.created_at,
        all_conversation_ids: conversation_group.map(&:id)
      )
    end.compact.sort_by do |conversation|
      conversation[:last_message_time] || conversation[:updated_at] || Time.zone.at(0)
    end.reverse
  end

  def serialized_last_message(message)
    return nil unless message

    status = if message.read_at.present?
      'read'
    elsif message.delivered_at.present?
      'delivered'
    else
      message.status.presence || 'sent'
    end

    {
      id: message.id,
      content: message.content,
      created_at: message.created_at,
      sender_type: message.sender_type,
      sender_id: message.sender_id,
      status: status,
      read_at: message.read_at,
      delivered_at: message.delivered_at
    }
  end

  def buyer_unread_count_for(conversation)
    conversation.messages
                .where(sender_type: ['Seller', 'Admin', 'SalesUser'])
                .where(read_at: nil)
                .count
  end

  def seller_unread_count_for(conversation)
    if conversation.seller_id.present? && conversation.inquirer_seller_id.present?
      conversation.messages
                  .where.not(sender_id: @current_user.id)
                  .where(read_at: nil)
                  .count
    else
      conversation.messages
                  .where(sender_type: ['Buyer', 'Admin', 'SalesUser'])
                  .where(read_at: nil)
                  .count
    end
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
