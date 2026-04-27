class NotificationsController < ApplicationController
  before_action :authenticate_request

  # GET /notifications
  def index
    per_page = (params[:per_page] || 50).to_i
    notifications = Notification.where(recipient: @current_user)
                                .order(created_at: :desc)
                                .limit(per_page)

    render json: {
      notifications: notifications.map { |n| serialize_notification(n) },
      meta: {
        total_count: Notification.where(recipient: @current_user).count,
        unread_count: Notification.where(recipient: @current_user, read_at: nil).count
      }
    }
  end

  # POST /api/notifications/:id/read
  def mark_as_read
    notification = Notification.find_by(id: params[:id], recipient: @current_user)

    if notification
      notification.mark_as_read!
      render json: { message: 'Notification marked as read', read_at: notification.read_at }
    else
      render json: { error: 'Notification not found' }, status: :not_found
    end
  end

  # POST /api/notifications/read_all
  def mark_all_as_read
    Notification.where(recipient: @current_user, read_at: nil).update_all(read_at: Time.current)
    render json: { message: 'All notifications marked as read' }
  end

  private

  def serialize_notification(notification)
    base = {
      id: notification.id,
      title: notification.title,
      body: notification.body,
      data: notification.data || {},
      read_at: notification.read_at,
      created_at: notification.created_at,
      notifiable_type: notification.notifiable_type,
      notifiable_id: notification.notifiable_id,
    }

    # Enrich with product/ad details when notifiable is an Ad
    if notification.notifiable_type == 'Ad' && notification.notifiable_id.present?
      ad = Ad.find_by(id: notification.notifiable_id)
      if ad
        base[:ad] = build_ad_context(ad)
      end
    end

    # Enrich from data hash – some notifications store ad_id directly
    if base[:ad].nil? && notification.data.is_a?(Hash)
      ad_id = notification.data['ad_id'] || notification.data[:ad_id]
      if ad_id.present?
        ad = Ad.find_by(id: ad_id)
        base[:ad] = build_ad_context(ad) if ad
      end
    end

    # Enrich with conversation context for message-related notifications
    if notification.notifiable_type == 'Conversation' && notification.notifiable_id.present?
      conversation = Conversation.find_by(id: notification.notifiable_id)
      if conversation
        base[:conversation] = {
          id: conversation.id,
          ad: conversation.ad ? build_ad_context(conversation.ad) : nil
        }
        # Promote ad from conversation if not already set
        if base[:ad].nil? && conversation.ad
          base[:ad] = build_ad_context(conversation.ad)
        end
      end
    end

    base
  end

  def build_ad_context(ad)
    return nil unless ad

    # Resolve active offer/discounted price
    active_offer_ad = ad.offer_ads.joins(:offer)
                        .where(offers: { status: 'active' })
                        .where('offers.start_time <= ? AND offers.end_time >= ?', Time.current, Time.current)
                        .where(is_active: true)
                        .order('offers.priority DESC')
                        .first rescue nil

    {
      id: ad.id,
      title: ad.title,
      price: ad.price,
      discounted_price: active_offer_ad&.discounted_price,
      original_price: active_offer_ad&.original_price || ad.price,
      discount_percentage: active_offer_ad&.discount_percentage,
      image_url: ad.first_media_url || ad.media_urls&.first,
      slug: ad.respond_to?(:slug) ? ad.slug : nil,
      category: ad.category&.name,
      subcategory: ad.subcategory&.name,
    }
  rescue => e
    Rails.logger.warn "NotificationsController#build_ad_context error: #{e.message}"
    nil
  end
end
