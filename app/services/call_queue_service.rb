# frozen_string_literal: true

class CallQueueService
  # Returns seller IDs that are currently in the queue (pending) or were resolved in the last 1 month
  def self.excluded_seller_ids_for_type(queue_type)
    CallQueue.where("reasons::jsonb @> ?", "[\"#{queue_type}\"]")
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

    # Collect all potential queue entries with their priorities
    all_entries = []

    # Collect sellers for each queue type
    all_entries.concat(collect_unread_messages_queue)
    all_entries.concat(collect_no_ads_uploaded_queue)
    all_entries.concat(collect_inactive_seller_queue)
    all_entries.concat(collect_new_seller_onboarding_queue)
    all_entries.concat(collect_document_expiry_queue)
    all_entries.concat(collect_proactive_outreach_queue)

    # Group by seller and collect all reasons for each seller
    seller_entries = {}
    all_entries.each do |entry|
      seller_id = entry[:seller_id]
      if seller_entries[seller_id].nil?
        seller_entries[seller_id] = {
          seller: entry[:seller],
          reasons: [],
          priorities: [],
          metadata: []
        }
      end
      seller_entries[seller_id][:reasons] << entry[:queue_type]
      seller_entries[seller_id][:priorities] << entry[:priority]
      seller_entries[seller_id][:metadata] << entry[:metadata]
    end

    # Create the queue entries with reasons array
    seller_entries.values.each do |entry|
      # Use highest priority
      max_priority = entry[:priorities].max
      # Combine all metadata
      combined_metadata = entry[:metadata].reduce({}, :merge)

      CallQueue.create!(
        seller: entry[:seller],
        reasons: entry[:reasons].uniq,
        priority: max_priority,
        metadata: combined_metadata
      )
    end

    # Cache the queue count for KPIs
    cache_queue_metrics
  end

  # Metric 1: Sellers with unread messages older than 24 hours
  def self.collect_unread_messages_queue
    entries = []
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

      entries << {
        seller_id: seller.id,
        seller: seller,
        queue_type: CallQueue::UNREAD_MESSAGES,
        priority: CallQueue::PRIORITY_HIGH,
        metadata: {
          unread_count: unread_count,
          oldest_message_age: seller.conversations.joins(:messages)
          .where(messages: { sender_type: 'Buyer', status: [nil, 'sent'] })
          .minimum('messages.created_at')&.to_s
        }
      }
    end
    entries
  end

  # Metric 2: Sellers who haven't uploaded ads in 14+ days
  def self.collect_no_ads_uploaded_queue
    entries = []
    sellers_no_ads = Seller.active
      .where('created_at < ?', 14.days.ago)
      .where('ads_count = 0 OR ads_count IS NULL')
      .where.not(id: excluded_seller_ids_for_type(CallQueue::NO_ADS_UPLOADED))

    sellers_no_ads.find_each do |seller|
      entries << {
        seller_id: seller.id,
        seller: seller,
        queue_type: CallQueue::NO_ADS_UPLOADED,
        priority: CallQueue::PRIORITY_MEDIUM,
        metadata: {
          days_since_creation: (Time.current - seller.created_at).to_i / 86400,
          last_ad_uploaded: nil
        }
      }
    end
    entries
  end

  # Metric 3: Inactive sellers (no activity for 7+ days)
  def self.collect_inactive_seller_queue
    entries = []
    inactive_sellers = Seller.active
      .where('last_active_at < ?', 7.days.ago)
      .where.not(id: excluded_seller_ids_for_type(CallQueue::INACTIVE_SELLER))

    inactive_sellers.find_each do |seller|
      days_inactive = (Time.current - seller.last_active_at).to_i / 86400
      priority = days_inactive > 30 ? CallQueue::PRIORITY_HIGH : CallQueue::PRIORITY_MEDIUM

      entries << {
        seller_id: seller.id,
        seller: seller,
        queue_type: CallQueue::INACTIVE_SELLER,
        priority: priority,
        metadata: {
          days_inactive: days_inactive,
          last_active_at: seller.last_active_at.to_s,
          total_ads: seller.ads_count
        }
      }
    end
    entries
  end

  # Metric 4: New sellers needing onboarding (3-7 days old, no ads)
  def self.collect_new_seller_onboarding_queue
    entries = []
    new_sellers = Seller.active
      .where(created_at: 3.days.ago..7.days.ago)
      .where('ads_count = 0 OR ads_count IS NULL')
      .where.not(id: excluded_seller_ids_for_type(CallQueue::NEW_SELLER_ONBOARDING))

    new_sellers.find_each do |seller|
      entries << {
        seller_id: seller.id,
        seller: seller,
        queue_type: CallQueue::NEW_SELLER_ONBOARDING,
        priority: CallQueue::PRIORITY_HIGH,
        metadata: {
          days_since_signup: (Time.current - seller.created_at).to_i / 86400,
          has_document: seller.document_verified?,
          location: seller.location
        }
      }
    end
    entries
  end


  # Metric 6: Document expiry within 30 days
  def self.collect_document_expiry_queue
    entries = []
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

      entries << {
        seller_id: seller.id,
        seller: seller,
        queue_type: CallQueue::DOCUMENT_EXPIRY,
        priority: priority,
        metadata: {
          document_type: expiring_doc.document_type&.name,
          expiry_date: expiring_doc.document_expiry_date.to_s,
          days_until_expiry: days_until_expiry
        }
      }
    end
    entries
  end

  # Metric 7: Proactive outreach - sellers doing well (active, have ads, recent activity)
  def self.collect_proactive_outreach_queue
    entries = []
    successful_sellers = Seller.active
      .where('ads_count > 0')
      .where('last_active_at > ?', 7.days.ago)
      .where('created_at < ?', 30.days.ago)
      .where.not(id: excluded_seller_ids_for_type(CallQueue::PROACTIVE_OUTREACH))

    successful_sellers.find_each do |seller|
      total_ads = seller.ads_count
      days_active = (Time.current - seller.created_at).to_i / 86400

      entries << {
        seller_id: seller.id,
        seller: seller,
        queue_type: CallQueue::PROACTIVE_OUTREACH,
        priority: CallQueue::PRIORITY_LOW,
        metadata: {
          total_ads: total_ads,
          days_active: days_active,
          last_active_at: seller.last_active_at.to_s
        }
      }
    end
    entries
  end


  # Cache queue metrics for KPI display
  def self.cache_queue_metrics
    queue_data = {
      total_count: CallQueue.pending.count,
      by_type: get_reasons_distribution,
      by_priority: CallQueue.pending.group(:priority).count
    }

    RedisConnection.setex('call_center:queue_metrics', 300, queue_data.to_json) # 5 minutes
  end
  
  # Get distribution of reasons across all pending queue entries
  def self.get_reasons_distribution
    distribution = {}
    CallQueue.pending.find_each do |queue|
      queue.reasons.each do |reason|
        distribution[reason] ||= 0
        distribution[reason] += 1
      end
    end
    distribution
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

    total_count = query.count

    # Map entries to API response format
    entries = query.map do |queue|
      seller = queue.seller
      {
        id: queue.id,
        seller_id: queue.seller_id,
        seller_name: seller.fullname,
        seller_email: seller.email,
        seller_phone: seller.phone_number,
        seller_enterprise: seller.enterprise_name,
        seller_profile_picture: seller.profile_picture && !seller.profile_picture.include?('googleusercontent.com') ? seller.profile_picture : nil,
        reasons: queue.reasons,
        reasons_display: queue.reasons.map { |r| CallQueue::QUEUE_TYPES[r] || r.humanize },
        priority: queue.priority,
        priority_display: priority_display(queue.priority),
        status: queue.status,
        metadata: queue.metadata,
        created_at: queue.created_at,
        days_in_queue: ((Time.current - queue.created_at).to_i / 86400).to_i
      }
    end

    # Sort by priority and created_at
    sorted_entries = entries.sort_by { |e| [-e[:priority], e[:created_at]] }

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
    when CallQueue::DOCUMENT_EXPIRY
      CallQueue::PRIORITY_CRITICAL
    when CallQueue::PROACTIVE_OUTREACH
      CallQueue::PRIORITY_LOW
    else
      CallQueue::PRIORITY_LOW
    end
  end
end
