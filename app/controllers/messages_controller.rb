class MessagesController < ApplicationController
  before_action :authenticate_user
  before_action :set_conversation

  def index
    case @current_user.class.name
    when 'Buyer'
      fetch_buyer_messages
    when 'Seller'
      fetch_seller_messages
    when 'Admin', 'SalesUser'
      fetch_admin_messages
    else
      render json: { error: 'Invalid user type' }, status: :unprocessable_entity
    end
  end

  def mark_as_read
    begin
      message_id = params[:id] || params[:message_id]
      message = @conversation.messages.find(message_id)
      
      if message && message.sender != @current_user
        message.mark_as_read!
        
        # Broadcast read receipt via WebSocket
        broadcast_read_receipt(message)
        
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
      Rails.logger.info "Message #{message_id} not found in conversation #{@conversation.id}, likely deleted"
      render json: { 
        success: true, 
        message_id: message_id, 
        status: 'not_found',
        note: 'Message no longer exists' 
      }
    end
  end

  def mark_as_delivered
    begin
      message_id = params[:id] || params[:message_id]
      message = @conversation.messages.find(message_id)
      
      if message && message.sender != @current_user
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
      Rails.logger.info "Message #{message_id} not found in conversation #{@conversation.id}, likely deleted"
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
      message = @conversation.messages.find(message_id)
      
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
      Rails.logger.info "Message #{message_id} not found in conversation #{@conversation.id}, likely deleted"
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
      # Message broadcasting is handled by the Message model's after_create callback
      render json: @message.as_json(include: :sender), status: :created
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
    # Try authenticating as different user types
    @current_user = authenticate_seller || authenticate_buyer || authenticate_admin || authenticate_sales_user
    
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
    # Handle seller-to-admin conversations
    if @conversation.admin_id.present?
      # This is a seller-admin conversation, just return messages from this conversation
      all_messages = @conversation.messages.order(created_at: :asc)
      messages_with_ads = all_messages.map do |message|
        message_data = build_message_data(message)
        add_ad_information(message_data, message)
        message_data
      end
      
      render json: {
        messages: messages_with_ads,
        total_messages: messages_with_ads.count
      }
      return
    end
    
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
    # Get all messages from this conversation, including ad info
    all_messages = @conversation.messages.order(created_at: :asc)
    
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
