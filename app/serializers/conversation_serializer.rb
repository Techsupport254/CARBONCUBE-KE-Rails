class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :admin_id, :buyer_id, :seller_id, :ad_id, :created_at, :updated_at, :inquirer_seller_id, :last_message,
             :admin, :buyer, :seller, :inquirer_seller, :ad

  def admin
    return nil unless object.admin
    {
      id: object.admin.id,
      fullname: object.admin.fullname,
      username: object.admin.username,
      email: object.admin.email,
      profile_picture: nil  # Admin model doesn't have profile_picture
    }
  end

  def buyer
    return nil unless object.buyer
    {
      id: object.buyer.id,
      fullname: object.buyer.fullname,
      username: object.buyer.username,
      email: object.buyer.email,
      phone_number: object.buyer.phone_number,
      profile_picture: resolve_profile_picture(object.buyer.profile_picture),
      last_active_at: object.buyer.last_active_at
    }
  end

  def seller
    return nil unless object.seller
    {
      id: object.seller.id,
      fullname: object.seller.fullname,
      username: object.seller.username,
      enterprise_name: object.seller.enterprise_name,
      email: object.seller.email,
      phone_number: object.seller.phone_number,
      profile_picture: resolve_profile_picture(object.seller.profile_picture),
      last_active_at: object.seller.last_active_at
    }
  end

  def inquirer_seller
    return nil unless object.inquirer_seller
    {
      id: object.inquirer_seller.id,
      fullname: object.inquirer_seller.fullname,
      username: object.inquirer_seller.username,
      enterprise_name: object.inquirer_seller.enterprise_name,
      email: object.inquirer_seller.email,
      phone_number: object.inquirer_seller.phone_number,
      profile_picture: resolve_profile_picture(object.inquirer_seller.profile_picture),
      last_active_at: object.inquirer_seller.last_active_at
    }
  end

  def ad
    return nil unless object.ad
    {
      id: object.ad.id,
      title: object.ad.title,
      price: object.ad.price,
      description: object.ad.description,
      media: object.ad.media
    }
  end

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

  private

  # Avoid using cached profile pictures - always return nil for cached URLs
  def resolve_profile_picture(url)
    return nil if url.blank?
    
    # If it's a cached profile picture URL, don't use it (return nil to avoid 404 errors)
    return nil if url.start_with?('/cached_profile_pictures/')
    
    # Return original Google URL or other valid URLs (but not cached ones)
    url
  end
end
