class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, polymorphic: true
  belongs_to :ad, optional: true

  validates :content, presence: true

  # Callbacks
  after_create :broadcast_new_message

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

  private

  def broadcast_new_message
    # Broadcast to buyer
    if conversation.buyer_id
      ActionCable.server.broadcast(
        "conversations_buyer_#{conversation.buyer_id}",
        {
          type: 'new_message',
          conversation_id: conversation.id,
          message: {
            id: id,
            content: content,
            created_at: created_at,
            sender_type: sender_type,
            sender_id: sender_id,
            ad_id: ad_id,
            product_context: product_context
          }
        }
      )
    end

    # Broadcast to seller
    if conversation.seller_id
      ActionCable.server.broadcast(
        "conversations_seller_#{conversation.seller_id}",
        {
          type: 'new_message',
          conversation_id: conversation.id,
          message: {
            id: id,
            content: content,
            created_at: created_at,
            sender_type: sender_type,
            sender_id: sender_id,
            ad_id: ad_id,
            product_context: product_context
          }
        }
      )
    end
  end
end

