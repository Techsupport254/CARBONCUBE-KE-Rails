class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, polymorphic: true
  belongs_to :ad, optional: true

  validates :content, presence: true

  # Callbacks
  after_create :broadcast_new_message
  after_create :schedule_delivery_receipt
  after_create :send_message_notification_email

  # Status constants
  STATUS_SENT = 'sent'
  STATUS_DELIVERED = 'delivered'
  STATUS_READ = 'read'

  # Scopes
  scope :unread, -> { where(status: [nil, STATUS_SENT]) }
  scope :delivered, -> { where(status: STATUS_DELIVERED) }
  scope :read, -> { where(status: STATUS_READ) }

  # Status methods
  def sent?
    status == STATUS_SENT || status.nil?
  end

  def delivered?
    status == STATUS_DELIVERED
  end

  def read?
    status == STATUS_READ
  end

  def mark_as_delivered!
    update!(status: STATUS_DELIVERED, delivered_at: Time.current)
  end

  def mark_as_read!
    update!(status: STATUS_READ, read_at: Time.current)
  end

  # Get status display text
  def status_text
    case status
    when STATUS_READ
      'read'
    when STATUS_DELIVERED
      'delivered'
    else
      'sent'
    end
  end

  # Get status icon
  def status_icon
    case status
    when STATUS_READ
      '✓✓' # Double check for read
    when STATUS_DELIVERED
      '✓' # Single check for delivered
    else
      '✓' # Single check for sent
    end
  end

  def schedule_delivery_receipt
    # Check if recipient is online before scheduling delivery
    recipient = get_recipient
    if recipient && is_recipient_online?(recipient)
      # Recipient is online - mark as delivered immediately
      Rails.logger.info "Recipient is online, marking message #{id} as delivered immediately"
      mark_as_delivered!
    else
      # Recipient is offline - schedule delivery for when they come online
      Rails.logger.info "Recipient is offline, scheduling delivery receipt for message #{id}"
      begin
        MessageDeliveryJob.perform_in(2.seconds, id)
      rescue NoMethodError => e
        # Fallback: if Sidekiq is not available, mark as delivered immediately
        Rails.logger.warn "Sidekiq not available, marking message as delivered immediately: #{e.message}"
        mark_as_delivered!
      rescue => e
        Rails.logger.error "Failed to schedule delivery receipt: #{e.message}"
        # Don't fail the message creation if delivery receipt scheduling fails
      end
    end
  end

  def broadcast_new_message
    Rails.logger.info "=== BROADCASTING NEW MESSAGE #{id} ==="
    Rails.logger.info "Conversation ID: #{conversation.id}"
    Rails.logger.info "Buyer ID: #{conversation.buyer_id}"
    Rails.logger.info "Seller ID: #{conversation.seller_id}"
    
    message_data = {
      id: id,
      content: content,
      created_at: created_at,
      sender_type: sender_type,
      sender_id: sender_id,
      sender: {
        id: sender.id,
        type: sender_type,
        name: get_sender_display_name(sender)
      },
      ad_id: ad_id,
      product_context: product_context,
      status: determine_status,
      status_text: status_text,
      status_icon: status_icon,
      read_at: read_at,
      delivered_at: delivered_at
    }

    broadcast_payload = {
      type: 'new_message',
      conversation_id: conversation.id,
      message: message_data
    }
    
    Rails.logger.info "Broadcast payload: #{broadcast_payload.inspect}"

    # Broadcast to buyer
    if conversation.buyer_id
      Rails.logger.info "Broadcasting message #{id} to buyer #{conversation.buyer_id}"
      ActionCable.server.broadcast(
        "conversations_buyer_#{conversation.buyer_id}",
        broadcast_payload
      )
    end

    # Broadcast to seller
    if conversation.seller_id
      Rails.logger.info "Broadcasting message #{id} to seller #{conversation.seller_id}"
      ActionCable.server.broadcast(
        "conversations_seller_#{conversation.seller_id}",
        broadcast_payload
      )
    end

    # Broadcast to inquirer seller (if different from main seller)
    if conversation.inquirer_seller_id && conversation.inquirer_seller_id != conversation.seller_id
      Rails.logger.info "Broadcasting message #{id} to inquirer seller #{conversation.inquirer_seller_id}"
      ActionCable.server.broadcast(
        "conversations_seller_#{conversation.inquirer_seller_id}",
        broadcast_payload
      )
    end

    # Update unread counts for all participants
    begin
      UpdateUnreadCountsJob.perform_now(conversation.id, id)
    rescue StandardError => e
      Rails.logger.warn "Failed to update unread counts for message #{id}: #{e.message}"
      # Fallback to queuing the job
      UpdateUnreadCountsJob.perform_later(conversation.id, id)
    end
  end

  def determine_status
    if read_at.present?
      'read'
    elsif delivered_at.present?
      'delivered'
    else
      status.present? ? status : 'sent'
    end
  end

  # Get the recipient of this message (not the sender)
  def get_recipient
    case sender_type
    when 'Buyer'
      # If buyer sent, recipient is seller
      Seller.find_by(id: conversation.seller_id)
    when 'Seller'
      # If seller sent, recipient is buyer
      Buyer.find_by(id: conversation.buyer_id)
    when 'Admin'
      # If admin sent, recipient depends on conversation
      if conversation.buyer_id
        Buyer.find_by(id: conversation.buyer_id)
      elsif conversation.seller_id
        Seller.find_by(id: conversation.seller_id)
      end
    else
      nil
    end
  end

  # Check if the recipient is currently online
  def is_recipient_online?(recipient)
    return false unless recipient
    
    user_type = recipient.class.name.downcase
    cache_key = "online_user_#{user_type}_#{recipient.id}"
    
    # Check both Rails cache and Redis for online status
    Rails.cache.exist?(cache_key) || RedisConnection.exists?(cache_key)
  rescue => e
    Rails.logger.warn "Failed to check online status for #{user_type}_#{recipient.id}: #{e.message}"
    false
  end

  # Send email notification to recipient
  def send_message_notification_email
    recipient = get_recipient
    return unless recipient
    
    # Don't send email if recipient is online (they'll see it in real-time)
    if is_recipient_online?(recipient)
      Rails.logger.info "Recipient #{recipient.class.name} #{recipient.id} is online, skipping email notification"
      return
    end
    
    # Don't send email to the sender
    if sender == recipient
      Rails.logger.info "Sender and recipient are the same, skipping email notification"
      return
    end
    
    begin
      MessageNotificationMailer.new_message_notification(self, recipient).deliver_now
      Rails.logger.info "Email notification sent to #{recipient.class.name} #{recipient.id} for message #{id}"
    rescue => e
      Rails.logger.error "Failed to send email notification for message #{id}: #{e.message}"
      # Don't fail message creation if email sending fails
    end
  end

  # Get display name for sender
  def get_sender_display_name(sender)
    case sender.class.name
    when 'Buyer'
      sender.username.present? ? sender.username : sender.email.split('@').first
    when 'Seller'
      sender.fullname.present? ? sender.fullname : sender.enterprise_name
    when 'Admin'
      'Carbon Cube Support'
    else
      sender.email.split('@').first
    end
  end
end

