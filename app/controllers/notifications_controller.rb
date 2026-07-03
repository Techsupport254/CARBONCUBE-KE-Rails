class NotificationsController < ApplicationController
  before_action :authenticate_request

  # GET /notifications
  def index
    per_page = (params[:per_page] || 50).to_i
    notifications = visible_notifications.first(per_page)

    render json: {
      notifications: notifications.map { |n| serialize_notification(n) },
      meta: {
        total_count: visible_notifications.length,
        unread_count: visible_notifications.count { |notification| notification.read_at.nil? }
      }
    }
  end

  # POST /api/notifications/:id/read
  def mark_as_read
    notification = visible_notifications.find { |item| item.id.to_s == params[:id].to_s }

    if notification
      notification.mark_as_read!
      render json: { message: 'Notification marked as read', read_at: notification.read_at }
    else
      render json: { error: 'Notification not found' }, status: :not_found
    end
  end

  # POST /api/notifications/read_all
  def mark_all_as_read
    visible_notification_ids = visible_notifications.select { |notification| notification.read_at.nil? }.map(&:id)
    Notification.where(recipient: @current_user, id: visible_notification_ids).update_all(read_at: Time.current)
    render json: { message: 'All notifications marked as read' }
  end

  private

  def current_branch
    return @current_branch if defined?(@current_branch)

    branch_id = request.headers['X-Branch-Id']
    @current_branch = if branch_id.present? && @current_user.respond_to?(:branches)
      @current_user.branches.find_by(id: branch_id)
    else
      nil
    end
  end

  def visible_notifications
    @visible_notifications ||= begin
      scope = Notification.where(recipient: @current_user).order(created_at: :desc).to_a
      branch = current_branch

      branch ? scope.select { |notification| notification_visible_for_branch?(notification, branch) } : scope
    end
  end

  def notification_visible_for_branch?(notification, branch)
    notification_branch_id = notification_branch_id(notification)
    return true if notification_branch_id.nil?

    notification_branch_id == branch.id
  end

  def notification_branch_id(notification)
    if notification.notifiable_type == 'Ad' && notification.notifiable_id.present?
      Ad.where(id: notification.notifiable_id).pick(:branch_id)
    elsif notification.notifiable_type == 'Conversation' && notification.notifiable_id.present?
      Conversation.joins(:ad).where(conversations: { id: notification.notifiable_id }).pick('ads.branch_id')
    elsif notification.data.is_a?(Hash)
      ad_id = notification.data['ad_id'] || notification.data[:ad_id]
      if ad_id.present?
        Ad.where(id: ad_id).pick(:branch_id)
      end
    end
  end

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
