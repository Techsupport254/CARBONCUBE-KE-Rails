class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :admin_id, :buyer_id, :seller_id, :ad_id, :created_at, :updated_at, :inquirer_seller_id, :last_message

  belongs_to :admin
  belongs_to :buyer
  belongs_to :seller
  belongs_to :inquirer_seller
  belongs_to :ad
  # has_many :messages

  def last_message
    message = object.messages.order(created_at: :desc).first
    return nil unless message
    
    # Determine status based on read_at/delivered_at (prioritize over existing status field)
    status = if message.read_at.present?
      'read'
    elsif message.delivered_at.present?
      'delivered'
    else
      message.status.present? ? message.status : 'sent'
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
end
