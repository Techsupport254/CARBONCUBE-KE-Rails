class MessagesController < ApplicationController
  before_action :authenticate_user
  before_action :set_conversation

  def index
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_messages
    when 'Seller'
      fetch_seller_messages
    when 'Admin', 'SalesUser', 'MarketingUser'
      fetch_admin_messages
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def mark_as_read
    # Sales users can now mark messages as read even if they are just viewing as support
    # (Previously restricted to direct participants)
    
    begin
      message_id = params[:id] || params[:message_id]
      message = find_message_for_status_update(message_id)
      
      if message && message.sender != @current_user
        # For staff roles, only mark as read if they are the assigned admin/salesperson
        is_staff = ['Admin', 'SalesUser', 'MarketingUser'].include?(@current_user.class.name)
        if is_staff && @conversation.admin_id != @current_user.id
          render json: { 
            success: true, 
            message: 'Viewer not assigned to conversation, skipping read receipt',
            status: message.status_text,
            read_at: message.read_at 
          }
          return
        end

        message.mark_as_read!
        
        # Broadcast read receipt via WebSocket
        broadcast_read_receipt(message)
        
        # Update unread counts for all participants after marking as read
        begin
          UpdateUnreadCountsJob.perform_now(@conversation.id, message.id)
        rescue StandardError => e
          Rails.logger.warn "Failed to update unread counts after marking message as read: #{e.message}"
          UpdateUnreadCountsJob.perform_later(@conversation.id, message.id)
        end
        
        render json: { 
          success: true, 
          message_id: message.id, 
          status: 'read',
          read_at: message.read_at 
        }
      else
        render json: { error: 'Message not found or unauthorized' }, status: :not_found
      end
    rescue ActiveRecord::RecordNotFound
      # Message doesn't exist - return success to prevent frontend errors
      Rails.logger.info "Message #{message_id} not found in conversation thread #{@conversation.id}, likely deleted"
      render json: { 
        success: true, 
        message_id: message_id, 
        status: 'not_found',
        note: 'Message no longer exists' 
      }
    end
  end

  def mark_as_delivered
    # Sales users can now mark messages as delivered even if they are just viewing as support
    # (Previously restricted to direct participants)
    
    begin
      message_id = params[:id] || params[:message_id]
      message = find_message_for_status_update(message_id)
      
      if message && message.sender != @current_user
        # For staff roles, only mark as delivered if they are the assigned admin/salesperson
        is_staff = ['Admin', 'SalesUser', 'MarketingUser'].include?(@current_user.class.name)
        if is_staff && @conversation.admin_id != @current_user.id
          render json: { 
            success: true, 
            message: 'Viewer not assigned to conversation, skipping delivery receipt',
            status: message.status_text,
            delivered_at: message.delivered_at 
          }
          return
        end

        message.mark_as_delivered!
        
        # Broadcast delivery receipt via WebSocket
        broadcast_delivery_receipt(message)
        
        render json: { 
          success: true, 
          message_id: message.id, 
          status: 'delivered',
          delivered_at: message.delivered_at 
        }
      else
        render json: { error: 'Message not found or unauthorized' }, status: :not_found
      end
    rescue ActiveRecord::RecordNotFound
      # Message doesn't exist - return success to prevent frontend errors
      Rails.logger.info "Message #{message_id} not found in conversation thread #{@conversation.id}, likely deleted"
      render json: { 
        success: true, 
        message_id: message_id, 
        status: 'not_found',
        note: 'Message no longer exists' 
      }
    end
  end

  def status
    begin
      message_id = params[:id] || params[:message_id]
      message = find_message_for_status_update(message_id)
      
      if message
        render json: {
          message_id: message.id,
          status: message.status_text,
          status_icon: message.status_icon,
          read_at: message.read_at,
          delivered_at: message.delivered_at,
          sent_at: message.created_at
        }
      else
        render json: { error: 'Message not found' }, status: :not_found
      end
    rescue ActiveRecord::RecordNotFound
      # Message doesn't exist - return not found status
      Rails.logger.info "Message #{message_id} not found in conversation thread #{@conversation.id}, likely deleted"
      render json: { 
        error: 'Message not found',
        message_id: params[:message_id],
        status: 'not_found'
      }, status: :not_found
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
      # If the sender is staff (Admin/SalesUser) and the conversation has no admin_id,
      # assign this staff member as the admin for the conversation
      if (@current_user.is_a?(Admin) || @current_user.is_a?(SalesUser)) && @conversation.admin_id.nil?
        @conversation.update(admin_id: @current_user.id)
        Rails.logger.info "Assigned Admin/SalesUser #{@current_user.id} to Conversation #{@conversation.id}"
      end

      # The broadcast is handled by the model, but for the immediate response
      # we need to ensure ad information is included for the sender
      message_data = build_message_data(@message)
      add_ad_information(message_data, @message)
      message_data[:sender] = @current_user.as_json
      
      render json: message_data, status: :created
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  def process_pending_deliveries
    # This endpoint can be called to manually process pending delivery receipts
    # Useful for testing or manual intervention
    begin
      user_type = @current_user.class.name.downcase
      user_id = @current_user.id
      
      # Find all sent messages where this user is the recipient
      pending_messages = case user_type
      when 'buyer'
        Message.joins(:conversation)
               .where(conversations: { buyer_id: user_id })
               .where(status: ['sent', nil])
               .where.not(sender_type: 'Buyer')
      when 'seller'
        Message.joins(:conversation)
               .where(conversations: { seller_id: user_id })
               .where(status: ['sent', nil])
               .where.not(sender_type: 'Seller')
      else
        []
      end
      
      # Mark these messages as delivered
      processed_count = 0
      pending_messages.each do |message|
        message.mark_as_delivered!
        broadcast_delivery_receipt(message)
        processed_count += 1
      end
      
      render json: { 
        success: true, 
        processed_count: processed_count,
        message: "Processed #{processed_count} pending delivery receipts"
      }
    rescue => e
      Rails.logger.error "Failed to process pending deliveries: #{e.message}"
      render json: { error: 'Failed to process pending deliveries' }, status: :internal_server_error
    end
  end

  def send_test_email
    # This endpoint can be used to test email notifications
    begin
      message = @conversation.messages.find(params[:message_id])
      recipient = message.get_recipient
      
      if recipient
        MessageNotificationMailer.new_message_notification(message, recipient).deliver_now
        render json: { 
          success: true, 
          message: "Test email sent to #{recipient.email}",
          recipient_email: recipient.email
        }
      else
        render json: { error: 'No recipient found for this message' }, status: :not_found
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Message not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Failed to send test email: #{e.message}"
      render json: { error: 'Failed to send test email' }, status: :internal_server_error
    end
  end

  private

  def authenticate_user
    # Check staff roles first to avoid noisy role-mismatch logs on shared message routes
    @current_user = authenticate_sales_user || authenticate_admin || authenticate_marketing_user || authenticate_seller || authenticate_buyer
    
    unless @current_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def authenticate_seller
    SellerAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken => e
    Rails.logger.debug "SellerAuthorizeApiRequest: #{e.message}"
    nil
  rescue => e
    Rails.logger.warn "SellerAuthorizeApiRequest: Unexpected error: #{e.message}"
    nil
  end

  def authenticate_buyer
    BuyerAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken => e
    Rails.logger.debug "BuyerAuthorizeApiRequest: #{e.message}"
    nil
  rescue => e
    Rails.logger.warn "BuyerAuthorizeApiRequest: Unexpected error: #{e.message}"
    nil
  end

  def authenticate_admin
    AdminAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_sales_user
    SalesAuthorizeApiRequest.new(request.headers).result
  rescue
    nil
  end

  def authenticate_marketing_user
    # MarketingUser tokens should be handled similarly to Admin/Sales
    # We use a general Staff token or their specific one if it exists
    # Assuming MarketingAuthorizeApiRequest exists or mirrors others
    # For now, let's use the same decoding logic as ConversationsController if needed
    # but let's assume there's a service.
    # Actually, looking at current code, they might not have a service yet.
    # Let's check list_dir for services.
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
                   end

    unless @conversation
      render json: { error: 'Conversation not found or unauthorized' }, status: :not_found
    end
  end

  def find_buyer_conversation
    Conversation.active_participants
                .find_by(id: params[:conversation_id], buyer_id: @current_user.id)
  end

  def find_seller_conversation
    # Find conversation where current seller is either the seller or the inquirer_seller
    Conversation.active_participants
                .where(
      id: params[:conversation_id]
    ).where(
      "(seller_id = ? OR inquirer_seller_id = ?)", 
      @current_user.id, 
      @current_user.id
    ).first
  end

  def find_admin_conversation
    # Admins and Sales users can access any conversation
    # But for Sales users, prefer conversations where they are the admin_id
    if @current_user.is_a?(SalesUser)
      # Try to find conversation where sales user is the admin_id first
      conversation = Conversation.active_participants
                                .find_by(id: params[:conversation_id], admin_id: @current_user.id)
      
      # If not found, allow access to any conversation (like admin)
      conversation || Conversation.active_participants.find_by(id: params[:conversation_id])
    else
      # Admins can access any conversation
      Conversation.active_participants.find_by(id: params[:conversation_id])
    end
  end

  def fetch_buyer_messages
    # Get all conversations with the same recipient (seller or admin)
    recipient_conv_ids = [@conversation.id]
    
    if @conversation.admin_id.present?
      # For admin/support threads, include all admin threads for this buyer
      admin_ids = Conversation.where(buyer_id: @current_user.id).where.not(admin_id: nil).pluck(:admin_id).uniq
      admin_conv_ids = Conversation.where(buyer_id: @current_user.id, admin_id: admin_ids).pluck(:id)
      recipient_conv_ids.concat(admin_conv_ids)
    else
      # Regular seller thread
      seller_conv_ids = Conversation.where(buyer_id: @current_user.id, seller_id: @conversation.seller_id).pluck(:id)
      recipient_conv_ids.concat(seller_conv_ids)
    end
    
    # Get all messages from related conversations
    all_messages = Message.where(conversation_id: recipient_conv_ids.uniq).order(created_at: :asc)
    
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
    recipient_conv_ids = [@conversation.id]
    
    # Determine if this is a Support/Admin thread (no buyer and either has admin_id or is WhatsApp)
    is_support_thread = @conversation.buyer_id.nil? && (@conversation.admin_id.present? || @conversation.is_whatsapp?)

    if is_support_thread
      # Aggregate all Support/Admin context for this seller
      admin_conv_ids = Conversation.where(seller_id: @current_user.id).where.not(admin_id: nil).pluck(:id)
      recipient_conv_ids.concat(admin_conv_ids)
      
      # Also include WhatsApp threads that might not have an admin_id yet
      unassigned_wa_conv_ids = Conversation.where(seller_id: @current_user.id, admin_id: nil, buyer_id: nil, is_whatsapp: true).pluck(:id)
      recipient_conv_ids.concat(unassigned_wa_conv_ids)
    elsif @conversation.buyer_id.present?
      # Regular buyer conversation
      buyer_conv_ids = Conversation.where(seller_id: @current_user.id, buyer_id: @conversation.buyer_id).pluck(:id)
      recipient_conv_ids.concat(buyer_conv_ids)
    elsif @conversation.inquirer_seller_id.present?
      # Seller-to-seller
      participant_id = @conversation.seller_id == @current_user.id ? @conversation.inquirer_seller_id : @conversation.seller_id
      s2s_conv_ids = Conversation.where(
        "(seller_id = ? AND inquirer_seller_id = ?) OR (seller_id = ? AND inquirer_seller_id = ?)",
        @current_user.id, participant_id, participant_id, @current_user.id
      ).pluck(:id)
      recipient_conv_ids.concat(s2s_conv_ids)
    end
    
    # Get all messages from related conversations
    all_messages = Message.where(conversation_id: recipient_conv_ids.uniq).order(created_at: :asc)
    
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
    # Get all conversations with the exact same participant set OR related support threads
    # This ensures marketing broadcasts (admin-seller) show up in reply threads
    related_conv_ids = [@conversation.id]
    
    if @conversation.seller_id.present?
      # Find any Admin-Seller conversation for this seller that doesn't have a buyer
      admin_seller_convs = Conversation.where(seller_id: @conversation.seller_id)
                                      .where(buyer_id: nil)
                                      .where.not(admin_id: nil)
                                      .pluck(:id)
      related_conv_ids.concat(admin_seller_convs)
    end
    
    if @conversation.buyer_id.present?
      # Find any Admin-Buyer conversation for this buyer that doesn't have a seller
      admin_buyer_convs = Conversation.where(buyer_id: @conversation.buyer_id)
                                     .where(seller_id: nil)
                                     .where.not(admin_id: nil)
                                     .pluck(:id)
      related_conv_ids.concat(admin_buyer_convs)
    end
    
    # Get all messages from these conversations, including ad info
    all_messages = Message.where(conversation_id: related_conv_ids.uniq).order(created_at: :asc)
    
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

  def build_message_data(message)
    {
      id: message.id,
      content: message.content,
      created_at: message.created_at,
      sender_type: message.sender_type,
      sender_id: message.sender_id,
      ad_id: message.ad_id,
      product_context: message.product_context,
      status: message.status,
      read_at: message.read_at,
      delivered_at: message.delivered_at
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

  def find_message_for_status_update(message_id)
    message = @conversation.messages.find_by(id: message_id)
    return message if message

    related_conversations_for_status_update.each do |conversation|
      next if conversation.id == @conversation.id

      related_message = conversation.messages.find_by(id: message_id)
      return related_message if related_message
    end

    raise ActiveRecord::RecordNotFound
  end

  def related_conversations_for_status_update
    case @current_user.class.name
    when 'Buyer'
      if @conversation.seller_id.present?
        Conversation.where(
          buyer_id: @current_user.id,
          seller_id: @conversation.seller_id
        ).active_participants
      else
        Conversation.where(id: @conversation.id)
      end
    when 'Seller'
      if @conversation.admin_id.present?
        Conversation.where(id: @conversation.id)
      elsif @conversation.buyer_id.present?
        Conversation.where(
          seller_id: @conversation.seller_id,
          buyer_id: @conversation.buyer_id
        ).active_participants
      elsif @conversation.inquirer_seller_id.present? && @conversation.seller_id == @current_user.id
        Conversation.where(
          seller_id: @current_user.id,
          inquirer_seller_id: @conversation.inquirer_seller_id
        ).active_participants
      elsif @conversation.inquirer_seller_id == @current_user.id && @conversation.seller_id.present?
        Conversation.where(
          seller_id: @conversation.seller_id,
          inquirer_seller_id: @current_user.id
        ).active_participants
      else
        Conversation.where(id: @conversation.id)
      end
    else
      Conversation.where(id: @conversation.id)
    end
  end

  def broadcast_read_receipt(message)
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    ActionCable.server.broadcast(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_read',
        message_id: message.id,
        conversation_id: message.conversation_id,
        read_at: message.read_at,
        status: 'read'
      }
    )
  end

  def broadcast_delivery_receipt(message)
    sender_type = message.sender_type.downcase
    sender_id = message.sender_id
    
    ActionCable.server.broadcast(
      "presence_#{sender_type}_#{sender_id}",
      {
        type: 'message_delivered',
        message_id: message.id,
        conversation_id: message.conversation_id,
        delivered_at: message.delivered_at,
        status: 'delivered'
      }
    )
  end
end
