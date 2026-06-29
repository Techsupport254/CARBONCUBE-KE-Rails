# frozen_string_literal: true

class CallQueueService
  # Returns seller IDs that are currently in the queue (pending) or were resolved in the last 1 month
  def self.excluded_seller_ids_for_type(queue_type)
    CallQueue.where(queue_type: queue_type)
      .where("status = ? OR (status = ? AND resolved_at > ?)", 
             CallQueue::STATUS_PENDING, 
             CallQueue::STATUS_RESOLVED, 
             1.month.ago)
      .select(:seller_id)
  end

  # Main method to populate the call queue based on metrics
  def self.populate_queue
    # Clear existing pending entries to avoid duplicates
    CallQueue.pending.delete_all

    # Calculate and add entries for each metric type
    add_unread_messages_queue
    add_no_ads_uploaded_queue
    add_inactive_seller_queue
    add_new_seller_onboarding_queue
    add_low_engagement_queue
    add_document_expiry_queue
    add_low_rating_queue

    # Cache the queue count for KPIs
    cache_queue_metrics
  end

  # Metric 1: Sellers with unread messages older than 24 hours
  def self.add_unread_messages_queue
    sellers_with_unread = Seller.active.joins(:conversations)
      .where(conversations: { updated_at: 24.hours.ago.. })
      .where.not(conversations: { seller_id: nil })
      .where.not(id: excluded_seller_ids_for_type(CallQueue::UNREAD_MESSAGES))
      .distinct

    sellers_with_unread.find_each do |seller|
      unread_count = seller.conversations.joins(:messages)
        .where(messages: { sender_type: 'Buyer', status: [nil, 'sent'] })
        .where('messages.created_at < ?', 24.hours.ago)
        .count

      next if unread_count.zero?

      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::UNREAD_MESSAGES,
        priority: CallQueue::PRIORITY_HIGH,
        metadata: {
          unread_count: unread_count,
          oldest_message_age: seller.conversations.joins(:messages)
          .where(messages: { sender_type: 'Buyer', status: [nil, 'sent'] })
          .minimum('messages.created_at')&.to_s
        }
      )
    end
  end

  # Metric 2: Sellers who haven't uploaded ads in 14+ days
  def self.add_no_ads_uploaded_queue
    # Remove sellers who now have ads from this queue (only pending ones)
    sellers_with_ads = Seller.active
      .where('ads_count > 0')
      .where(id: CallQueue.pending.where(queue_type: CallQueue::NO_ADS_UPLOADED).select(:seller_id))
    
    CallQueue.pending.where(queue_type: CallQueue::NO_ADS_UPLOADED, seller_id: sellers_with_ads).destroy_all

    # Add sellers who still have no ads
    sellers_no_ads = Seller.active
      .where('created_at < ?', 14.days.ago)
      .where('ads_count = 0 OR ads_count IS NULL')
      .where.not(id: excluded_seller_ids_for_type(CallQueue::NO_ADS_UPLOADED))

    sellers_no_ads.find_each do |seller|
      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::NO_ADS_UPLOADED,
        priority: CallQueue::PRIORITY_MEDIUM,
        metadata: {
          days_since_creation: (Time.current - seller.created_at).to_i / 86400,
          last_ad_uploaded: nil
        }
      )
    end
  end

  # Metric 3: Inactive sellers (no activity for 7+ days)
  def self.add_inactive_seller_queue
    inactive_sellers = Seller.active
      .where('last_active_at < ?', 7.days.ago)
      .where.not(id: excluded_seller_ids_for_type(CallQueue::INACTIVE_SELLER))

    inactive_sellers.find_each do |seller|
      days_inactive = (Time.current - seller.last_active_at).to_i / 86400
      priority = days_inactive > 30 ? CallQueue::PRIORITY_HIGH : CallQueue::PRIORITY_MEDIUM

      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::INACTIVE_SELLER,
        priority: priority,
        metadata: {
          days_inactive: days_inactive,
          last_active_at: seller.last_active_at.to_s,
          total_ads: seller.ads_count
        }
      )
    end
  end

  # Metric 4: New sellers needing onboarding (3-7 days old, no ads)
  def self.add_new_seller_onboarding_queue
    new_sellers = Seller.active
      .where(created_at: 3.days.ago..7.days.ago)
      .where('ads_count = 0 OR ads_count IS NULL')
      .where.not(id: excluded_seller_ids_for_type(CallQueue::NEW_SELLER_ONBOARDING))

    new_sellers.find_each do |seller|
      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::NEW_SELLER_ONBOARDING,
        priority: CallQueue::PRIORITY_HIGH,
        metadata: {
          days_since_signup: (Time.current - seller.created_at).to_i / 86400,
          has_document: seller.document_verified?,
          location: seller.location
        }
      )
    end
  end

  # Metric 5: Low engagement sellers (<3 conversations in 30 days)
  def self.add_low_engagement_queue
    low_engagement_sellers = Seller.active
      .joins(:conversations)
      .where('conversations.created_at > ?', 30.days.ago)
      .group('sellers.id')
      .having('COUNT(conversations.id) < 3')
      .where.not(id: excluded_seller_ids_for_type(CallQueue::LOW_ENGAGEMENT))

    low_engagement_sellers.find_each do |seller|
      conversation_count = seller.conversations.where('created_at > ?', 30.days.ago).count

      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::LOW_ENGAGEMENT,
        priority: CallQueue::PRIORITY_LOW,
        metadata: {
          conversation_count_30d: conversation_count,
          total_ads: seller.ads_count
        }
      )
    end
  end

  # Metric 6: Document expiry within 30 days
  def self.add_document_expiry_queue
    expiring_sellers = Seller.active
      .joins(:seller_documents)
      .where('seller_documents.document_expiry_date > ?', Time.current)
      .where('seller_documents.document_expiry_date < ?', 30.days.from_now)
      .where.not(id: excluded_seller_ids_for_type(CallQueue::DOCUMENT_EXPIRY))
      .distinct

    expiring_sellers.find_each do |seller|
      expiring_doc = seller.seller_documents
        .where('document_expiry_date > ?', Time.current)
        .where('document_expiry_date < ?', 30.days.from_now)
        .order(document_expiry_date: :asc)
        .first

      days_until_expiry = ((expiring_doc.document_expiry_date - Time.current).to_i / 86400).to_i
      priority = days_until_expiry < 7 ? CallQueue::PRIORITY_CRITICAL : CallQueue::PRIORITY_HIGH

      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::DOCUMENT_EXPIRY,
        priority: priority,
        metadata: {
          document_type: expiring_doc.document_type&.name,
          expiry_date: expiring_doc.document_expiry_date.to_s,
          days_until_expiry: days_until_expiry
        }
      )
    end
  end

  # Metric 7: Low ratings (< 3.0 average)
  def self.add_low_rating_queue
    low_rated_sellers = Seller.active
      .joins(:reviews_received)
      .group('sellers.id')
      .having('AVG(reviews.rating) < 3.0')
      .where.not(id: excluded_seller_ids_for_type(CallQueue::LOW_RATING))
      .distinct

    low_rated_sellers.find_each do |seller|
      avg_rating = seller.reviews_received.average(:rating).to_f
      total_reviews = seller.reviews_received.count

      CallQueue.create!(
        seller: seller,
        queue_type: CallQueue::LOW_RATING,
        priority: CallQueue::PRIORITY_MEDIUM,
        metadata: {
          average_rating: avg_rating.round(2),
          total_reviews: total_reviews
        }
      )
    end
  end

  # Cache queue metrics for KPI display
  def self.cache_queue_metrics
    queue_data = {
      total_count: CallQueue.pending.count,
      by_type: CallQueue.pending.group(:queue_type).count,
      by_priority: CallQueue.pending.group(:priority).count
    }

    RedisConnection.setex('call_center:queue_metrics', 300, queue_data.to_json) # 5 minutes
  end

  # Get queue data for API response
  def self.get_queue_data(page: 1, per_page: 50, queue_type: nil, priority: nil, search: nil)
    query = CallQueue.pending
    query = query.by_type(queue_type) if queue_type.present?
    query = query.where(priority: priority.to_i) if priority.present?
    
    # Search by seller name, phone, email, or enterprise
    if search.present?
      search_term = "%#{search}%"
      # Use subquery for seller IDs to avoid joins in main query
      seller_ids = Seller.where(
        'fullname ILIKE ? OR phone_number ILIKE ? OR email ILIKE ? OR enterprise_name ILIKE ?',
        search_term, search_term, search_term, search_term
      ).pluck(:id)
      if seller_ids.any?
        query = query.where(seller_id: seller_ids)
      else
        query = query.where(id: nil) # Return empty if no seller matches search
      end
    end
    
    # Always use includes to avoid N+1 queries
    query = query.includes(:seller)
    
    total_count = query.distinct.count(:seller_id)
    
    # Group by seller to avoid duplicates
    grouped_entries = query.group_by(&:seller_id).map do |seller_id, entries|
      seller = entries.first.seller
      # Get all queue types for this seller
      queue_types = entries.map(&:queue_type)
      # Get highest priority
      max_priority = entries.map(&:priority).max
      # Get earliest created_at
      earliest_created = entries.map(&:created_at).min
      # Get all queue IDs for actions
      queue_ids = entries.map(&:id)
      
      {
        id: queue_ids.first, # Use first ID for reference
        queue_ids: queue_ids, # All IDs for bulk actions
        seller_id: seller_id,
        seller_name: seller.fullname,
        seller_email: seller.email,
        seller_phone: seller.phone_number,
        seller_enterprise: seller.enterprise_name,
        seller_profile_picture: seller.profile_picture,
        queue_types: queue_types,
        queue_type_display: queue_types.map { |qt| qt.humanize }.join(', '),
        priority: max_priority,
        priority_display: priority_display(max_priority),
        status: 'pending',
        metadata: entries.map(&:metadata),
        created_at: earliest_created,
        days_in_queue: ((Time.current - earliest_created).to_i / 86400).to_i
      }
    end
    
    # Sort by priority and created_at
    sorted_entries = grouped_entries.sort_by { |e| [-e[:priority], e[:created_at]] }
    
    # Apply pagination
    paginated_entries = sorted_entries.slice((page - 1) * per_page, per_page) || []

    {
      queue: paginated_entries,
      total_count: total_count,
      total_pages: (total_count.to_f / per_page).ceil,
      current_page: page
    }
  end

  def self.priority_display(priority)
    case priority
    when 3 then 'Critical'
    when 2 then 'High'
    when 1 then 'Medium'
    when 0 then 'Low'
    else 'Unknown'
    end
  end

  # Get priority level for a specific queue type
  def self.get_priority_for_type(queue_type)
    case queue_type
    when CallQueue::UNREAD_MESSAGES
      CallQueue::PRIORITY_HIGH
    when CallQueue::NO_ADS_UPLOADED
      CallQueue::PRIORITY_MEDIUM
    when CallQueue::INACTIVE_SELLER
      CallQueue::PRIORITY_HIGH
    when CallQueue::NEW_SELLER_ONBOARDING
      CallQueue::PRIORITY_HIGH
    when CallQueue::LOW_ENGAGEMENT
      CallQueue::PRIORITY_LOW
    when CallQueue::DOCUMENT_EXPIRY
      CallQueue::PRIORITY_CRITICAL
    when CallQueue::LOW_RATING
      CallQueue::PRIORITY_MEDIUM
    else
      CallQueue::PRIORITY_LOW
    end
  end
end
