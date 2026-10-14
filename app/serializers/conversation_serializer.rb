class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :admin_id, :buyer_id, :seller_id, :ad_id, :created_at, :updated_at, :inquirer_seller_id, :last_message,
             :admin, :buyer, :seller, :inquirer_seller, :ad, :is_whatsapp,
             :whatsapp_window_open, :whatsapp_window_expires_at

  def whatsapp_window_open
    return true unless object.is_whatsapp?
    expires_at = whatsapp_window_expires_at
    return false unless expires_at
    Time.zone.parse(expires_at) > Time.current
  end

  def whatsapp_window_expires_at
    return nil unless object.is_whatsapp?
    last_customer_msg = object.messages.where(sender_type: %w[Buyer Seller]).order(created_at: :desc).first
    return nil unless last_customer_msg
    (last_customer_msg.created_at + 24.hours).iso8601
  end

  def admin
    admin_user = object.admin
    if admin_user.nil? && object.admin_id.present?
      if scope.is_a?(Hash) && scope[:staff_lookup]
        admin_user = scope[:staff_lookup][object.admin_id]
      else
        admin_user = SalesUser.find_by(id: object.admin_id) ||
                     MarketingUser.find_by(id: object.admin_id)
      end
    end
    return nil unless admin_user

    user_role =
      case admin_user
      when SalesUser
        'sales'
      when MarketingUser
        'marketing'
      else
        'admin'
      end

    {
      id: admin_user.id,
      fullname: admin_user.fullname,
      username: admin_user.try(:username) || admin_user.fullname,
      email: admin_user.email,
      phone_number: admin_user.try(:phone_number),
      role: user_role,
      profile_picture: resolve_profile_picture(admin_user.try(:profile_picture)),
      profile_picture_url: resolve_profile_picture(admin_user.try(:profile_picture))
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
    serialize_seller(object.seller)
  end

  def inquirer_seller
    serialize_seller(object.inquirer_seller)
  end

  private

  def serialize_seller(seller_obj)
    return nil unless seller_obj

    main_branch = if seller_obj.association(:branches).loaded?
                    seller_obj.branches.min_by { |b| [b.is_main_branch ? 0 : 1, b.id] }
                  else
                    seller_obj.branches.order(is_main_branch: :desc, id: :asc).first
                  end

    {
      id: seller_obj.id,
      fullname: seller_obj.fullname,
      username: seller_obj.username,
      slug: seller_obj.url_slug,
      enterprise_name: seller_obj.enterprise_name,
      email: seller_obj.email,
      phone_number: seller_obj.phone_number,
      profile_picture: resolve_profile_picture(seller_obj.profile_picture),
      last_active_at: seller_obj.last_active_at,
      location: seller_obj.location,
      building: seller_obj.building,
      room: seller_obj.room,
      document_verified: seller_obj.document_verified,
      tier_id: seller_obj.try(:tier_id) || seller_obj.seller_tier&.tier_id || 1,
      tier_name: seller_obj.try(:tier_name) || seller_obj.tier&.name || 'Free',
      latitude: main_branch&.latitude&.to_f,
      longitude: main_branch&.longitude&.to_f,
      primary_branch_name: main_branch&.name,
      primary_branch_address: main_branch&.try(:location) || main_branch&.try(:address)
    }
  end

  public

  def ad
    return nil unless object.ad
    {
      id: object.ad.id,
      slug: object.ad.url_slug,
      title: object.ad.title,
      price: object.ad.price,
      description: object.ad.description,
      image: object.ad.first_media_url,
      first_media_url: object.ad.first_media_url,
      media_urls: object.ad.media_urls,
      media: object.ad.media,
      category: object.ad.category&.name,
      location: object.ad.try(:seller)&.try(:location),
      condition: object.ad.try(:condition),
      brand: object.ad.try(:brand)
    }
  end

  def last_message
    message = if scope.is_a?(Hash) && scope[:last_messages]
      scope[:last_messages][object.id]
    else
      object.messages.order(created_at: :desc).first
    end
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
      content: strip_markdown(message.content),
      created_at: message.created_at,
      sender_type: message.sender_type,
      sender_id: message.sender_id,
      status: status,
      read_at: message.read_at,
      delivered_at: message.delivered_at
    }
  end

  private

  def strip_markdown(text)
    return "" if text.blank?
    text.to_s
      .gsub(/^#+\s+/, '')
      .gsub(/\*\*(.*?)\*\*/, '\1')
      .gsub(/\*(.*?)\*/, '\1')
      .gsub(/__(.*?)__/, '\1')
      .gsub(/_(.*?)_/, '\1')
      .gsub(/\[(.*?)\]\(.*?\)/, '\1')
      .gsub(/`+(.*?)`+/, '\1')
      .gsub(/^\s*[-*+]\s+/, '')
  end

  # Avoid using cached profile pictures - always return nil for cached URLs
  def resolve_profile_picture(url)
    return nil if url.blank?
    
    # If it's a cached profile picture URL, don't use it (return nil to avoid 404 errors)
    return nil if url.start_with?('/cached_profile_pictures/')
    
    # Return original Google URL or other valid URLs (but not cached ones)
    url
  end
end
