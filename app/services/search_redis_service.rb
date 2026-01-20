class SearchRedisService
  # Service for handling search logging and analytics using Redis
  # This separates search operations from the main PostgreSQL database

  SEARCH_TTL = 30.days.to_i  # Individual search logs expire after 30 days
  ANALYTICS_TTL = 90.days.to_i  # Analytics data expires after 90 days

  class << self
    # Log a search query to Redis
    # @param search_term [String] the search term
    # @param buyer_id [String, nil] buyer UUID if authenticated, nil for guests
    # @param role [String, nil] user role (buyer, seller, admin, sales, guest)
    # @param metadata [Hash] additional metadata (device_hash, user_agent, etc.)
    def log_search(search_term, buyer_id = nil, role = nil, metadata = {})
      return if search_term.blank?

      session_id = metadata[:session_id] || metadata[:device_hash] || 'unknown'
      device_hash = metadata[:device_hash].to_s

      # Check for duplicate logging within the same session (backend protection)
      if duplicate_search_recently?(search_term, buyer_id, session_id, device_hash)
        Rails.logger.info "Duplicate search '#{search_term}' detected for session #{session_id}, skipping"
        return
      end

      timestamp = Time.current.to_i
      search_key = generate_search_key(timestamp, buyer_id)

      # Store individual search record (expires after 30 days)
      RedisConnection.with do |redis|
        # Store the search record as a hash
        redis.hmset(search_key,
          'search_term', search_term,
          'buyer_id', buyer_id.to_s,
          'role', role.to_s,
          'timestamp', timestamp,
          'device_hash', device_hash,
          'user_agent', metadata[:user_agent].to_s,
          'ip_address', metadata[:ip_address].to_s,
          'session_id', session_id,
          'logged_at', metadata[:logged_at] || Time.current.iso8601
        )

        redis.expire(search_key, SEARCH_TTL)

        # Track recent searches per session to prevent duplicates
        session_key = "searches:session:#{session_id}:recent"
        redis.zadd(session_key, timestamp, search_term)
        # Keep only last 10 searches per session, expire after 1 hour
        redis.zremrangebyrank(session_key, 0, -11)
        redis.expire(session_key, 1.hour.to_i)

        # Add to daily search set for analytics
        daily_key = "searches:daily:#{Date.current.iso8601}"
        redis.sadd(daily_key, search_term)
        redis.expire(daily_key, ANALYTICS_TTL)

        # Increment search term popularity
        popularity_key = "searches:popular"
        redis.zincrby(popularity_key, 1, search_term)
        redis.expire(popularity_key, ANALYTICS_TTL)

        # Track buyer search history if authenticated
        if buyer_id.present?
          buyer_history_key = "searches:buyer:#{buyer_id}:history"
          redis.zadd(buyer_history_key, timestamp, search_term)
          redis.expire(buyer_history_key, ANALYTICS_TTL)
        end

        # Track guest searches by device_hash
        if buyer_id.blank? && device_hash.present?
          guest_history_key = "searches:guest:#{device_hash}:history"
          redis.zadd(guest_history_key, timestamp, search_term)
          redis.expire(guest_history_key, ANALYTICS_TTL)
        end
      end

      Rails.logger.info "Search '#{search_term}' logged successfully for session #{session_id}"
    rescue => e
      Rails.logger.error "Failed to log search to Redis: #{e.message}"
      # Don't raise error - search logging shouldn't break the search functionality
    end

    # Get popular search terms
    # @param limit [Integer] number of terms to return
    # @param timeframe [Symbol] :all, :daily, :weekly, :monthly
    def popular_searches(limit = 20, timeframe = :all)
      RedisConnection.with do |redis|
        case timeframe
        when :daily
          # Count actual daily search frequencies by querying individual records
          start_of_day = Date.current.beginning_of_day.to_i
          end_of_day = Date.current.end_of_day.to_i

          # Get all search keys for today
          pattern = "searches:search:*"
          all_keys = redis.keys(pattern)

          # Count term frequencies for today's searches
          term_counts = Hash.new(0)
          all_keys.each do |key|
            timestamp = redis.hget(key, 'timestamp').to_i
            if timestamp >= start_of_day && timestamp <= end_of_day
              term = redis.hget(key, 'search_term')
              term_counts[term] += 1 if term.present?
            end
          end

          # Return most popular terms for today with their counts
          term_counts.sort_by { |_, count| -count }.first(limit)
        when :weekly
          # Aggregate last 7 days
          keys = (0..6).map { |i| "searches:daily:#{(Date.current - i.days).iso8601}" }
          aggregate_daily_searches(redis, keys, limit)
        when :monthly
          # Aggregate last 30 days
          keys = (0..29).map { |i| "searches:daily:#{(Date.current - i.days).iso8601}" }
          aggregate_daily_searches(redis, keys, limit)
        else
          # All time popular
          redis.zrevrange("searches:popular", 0, limit - 1, with_scores: true)
        end
      end
    end

    # Get search analytics
    def analytics
      RedisConnection.with do |redis|
        {
          total_searches_today: redis.scard("searches:daily:#{Date.current.iso8601}"),
          unique_search_terms_today: redis.scard("searches:daily:#{Date.current.iso8601}"),
          popular_searches: redis.zrevrange("searches:popular", 0, 9, with_scores: true),
          total_search_records: redis.keys("searches:search:*").size
        }
      end
    end

    # Get recent searches for a buyer
    # @param buyer_id [String] buyer UUID
    # @param limit [Integer] number of recent searches to return
    def recent_searches_for_buyer(buyer_id, limit = 10)
      return [] if buyer_id.blank?

      RedisConnection.with do |redis|
        key = "searches:buyer:#{buyer_id}:history"
        redis.zrevrange(key, 0, limit - 1, with_scores: true).map do |term, score|
          {
            search_term: term,
            timestamp: Time.at(score.to_i)
          }
        end
      end
    end

    # Get search history for admin interface
    # @param page [Integer] page number (1-based)
    # @param per_page [Integer] records per page
    # @param filters [Hash] optional filters (buyer_id, search_term, date_range)
    def search_history(page: 1, per_page: 50, filters: {})
      RedisConnection.with do |redis|
        # Get all search keys
        pattern = "searches:search:*"
        all_keys = redis.keys(pattern)

        # Apply filters if provided
        filtered_keys = apply_filters(all_keys, filters, redis)

        # Sort by timestamp (newest first) and paginate
        start_index = (page - 1) * per_page
        end_index = start_index + per_page - 1

        sorted_keys = filtered_keys.sort_by do |key|
          redis.hget(key, 'timestamp').to_i
        end.reverse

        paginated_keys = sorted_keys[start_index..end_index] || []
        total_count = filtered_keys.size

        # Fetch search records
        searches = paginated_keys.map do |key|
          data = redis.hgetall(key)
          next if data.empty?

          {
            id: key.split(':').last,
            search_term: data['search_term'],
            buyer_id: data['buyer_id'].present? ? data['buyer_id'] : nil,
            role: data['role'].present? ? data['role'] : 'guest',
            timestamp: Time.at(data['timestamp'].to_i),
            created_at: Time.at(data['timestamp'].to_i),
            device_hash: data['device_hash'],
            user_agent: data['user_agent'],
            ip_address: data['ip_address']
          }
        end.compact

        {
          searches: searches,
          total_count: total_count,
          current_page: page,
          per_page: per_page,
          total_pages: (total_count.to_f / per_page).ceil
        }
      end
    end

    # Clean up expired data (optional maintenance method)
    def cleanup_expired_data
      RedisConnection.with do |redis|
        # This is mainly handled by Redis TTL, but we can add custom cleanup if needed
        Rails.logger.info "Redis search cleanup completed"
      end
    end

    private

    def generate_search_key(timestamp, buyer_id)
      # Create a unique key for each search
      "searches:search:#{timestamp}:#{buyer_id || 'guest'}:#{SecureRandom.hex(4)}"
    end

    def duplicate_search_recently?(search_term, buyer_id, session_id, device_hash)
      return false if session_id == 'unknown'

      RedisConnection.with do |redis|
        session_key = "searches:session:#{session_id}:recent"

        # Check if this exact search term was logged in the last 30 seconds for this session
        recent_searches = redis.zrangebyscore(session_key, Time.current.to_i - 30, Time.current.to_i, with_scores: true)

        # Look for exact match (same search term recently)
        recent_searches.any? { |term, timestamp| term == search_term && (Time.current.to_i - timestamp.to_i) < 30 }
      end
    rescue => e
      Rails.logger.warn "Error checking for duplicate search: #{e.message}"
      false # Don't block logging if Redis check fails
    end

    def aggregate_daily_searches(redis, keys, limit)
      term_counts = Hash.new(0)

      keys.each do |key|
        searches = redis.smembers(key) || []
        searches.each { |term| term_counts[term] += 1 }
      end

      term_counts.sort_by { |_, count| -count }.first(limit)
    end

    def apply_filters(keys, filters, redis)
      return keys if filters.empty?

      keys.select do |key|
        data = redis.hgetall(key)
        next false if data.empty?

        matches = true

        # Filter by buyer_id
        if filters[:buyer_id].present?
          matches &= (data['buyer_id'] == filters[:buyer_id])
        end

        # Filter by search_term (partial match)
        if filters[:search_term].present?
          matches &= data['search_term'].to_s.downcase.include?(filters[:search_term].downcase)
        end

        # Filter by date range
        if filters[:start_date].present? && filters[:end_date].present?
          timestamp = data['timestamp'].to_i
          start_ts = filters[:start_date].to_time.to_i
          end_ts = filters[:end_date].to_time.to_i
          matches &= (timestamp >= start_ts && timestamp <= end_ts)
        end

        matches
      end
    end
  end
end