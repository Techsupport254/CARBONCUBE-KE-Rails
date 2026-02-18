class SearchRedisService
  class << self
    # @param search_term [String] the search term
    # @param user_id [String, nil] user UUID if authenticated, nil for guests
    # @param role [String, nil] user role (buyer, seller, admin, sales, guest)
    # @param metadata [Hash] additional metadata (device_hash, user_agent, etc.)
    def log_search(search_term, user_id = nil, role = nil, metadata = {})
      return if search_term.blank?

      session_id = metadata[:session_id] || metadata[:device_hash] || 'unknown'
      device_hash = metadata[:device_hash].to_s

      if duplicate_search_recently?(search_term, user_id, session_id, device_hash)
        Rails.logger.info "Duplicate search '#{search_term}' detected for session #{session_id}, skipping"
        return
      end

      timestamp = Time.current.to_i
      search_key = generate_search_key(timestamp, user_id, role)

      RedisConnection.with do |redis|
        redis.hmset(search_key,
          'search_term', search_term,
          'user_id', user_id.to_s,
          'role', role.to_s,
          'timestamp', timestamp,
          'device_hash', device_hash,
          'user_agent', metadata[:user_agent].to_s,
          'ip_address', metadata[:ip_address].to_s,
          'session_id', session_id,
          'logged_at', metadata[:logged_at] || Time.current.iso8601
        )

        session_key = "searches:session:#{session_id}:recent"
        redis.zadd(session_key, timestamp, search_term)

        daily_key = "searches:daily:#{Date.current.iso8601}"
        redis.sadd(daily_key, search_term)

        popularity_key = "searches:popular"
        redis.zincrby(popularity_key, 1, search_term)

        if user_id.present? && role.present?
          case role.to_s.downcase
          when 'buyer'
            redis.zadd("searches:buyer:#{user_id}:history", timestamp, search_term)
          when 'seller'
            redis.zadd("searches:seller:#{user_id}:history", timestamp, search_term)
          when 'admin'
            redis.zadd("searches:admin:#{user_id}:history", timestamp, search_term)
          when 'sales'
            redis.zadd("searches:sales:#{user_id}:history", timestamp, search_term)
          end
        end

        if user_id.blank? && device_hash.present?
          redis.zadd("searches:guest:#{device_hash}:history", timestamp, search_term)
        end
      end

      # Rails.logger.info "Search '#{search_term}' logged successfully for session #{session_id} (role: #{role}, user_id: #{user_id})"
    rescue => e
      Rails.logger.error "Failed to log search to Redis: #{e.message}"
    end

    # @param limit [Integer] number of terms to return
    # @param timeframe [Symbol] :all, :daily, :weekly, :monthly
    def popular_searches(limit = 20, timeframe = :all)
      RedisConnection.with do |redis|
        case timeframe
        when :daily
          start_of_day = Date.current.beginning_of_day.to_i
          end_of_day = Date.current.end_of_day.to_i
          all_keys = redis.keys("searches:search:*")

          term_counts = Hash.new(0)
          all_keys.each do |key|
            timestamp = redis.hget(key, 'timestamp').to_i
            if timestamp >= start_of_day && timestamp <= end_of_day
              term = redis.hget(key, 'search_term')
              term_counts[term] += 1 if term.present?
            end
          end

          term_counts.sort_by { |_, count| -count }.first(limit)
        when :weekly
          keys = (0..6).map { |i| "searches:daily:#{(Date.current - i.days).iso8601}" }
          aggregate_daily_searches(redis, keys, limit)
        when :monthly
          keys = (0..29).map { |i| "searches:daily:#{(Date.current - i.days).iso8601}" }
          aggregate_daily_searches(redis, keys, limit)
        else
          redis.zrevrange("searches:popular", 0, limit - 1, with_scores: true)
        end
      end
    end

    def analytics
      RedisConnection.with do |redis|
        today_key = "searches:daily:#{Date.current.iso8601}"
        weekly_keys = (0..6).map { |i| "searches:daily:#{(Date.current - i.days).iso8601}" }
        total_searches_weekly = weekly_keys.sum { |key| redis.scard(key) }

        {
          total_searches_today: redis.scard(today_key),
          unique_search_terms_today: redis.scard(today_key),
          total_searches_weekly: total_searches_weekly,
          popular_searches: redis.zrevrange("searches:popular", 0, 9, with_scores: true),
          total_search_records: redis.keys("searches:search:*").size
        }
      end
    end

    # @param user_id [String] user UUID
    # @param role [String] user role (buyer, seller, admin, sales)
    # @param limit [Integer] number of recent searches to return
    def recent_searches_for_user(user_id, role, limit = 10)
      return [] if user_id.blank? || role.blank?

      RedisConnection.with do |redis|
        case role.to_s.downcase
        when 'buyer'
          key = "searches:buyer:#{user_id}:history"
        when 'seller'
          key = "searches:seller:#{user_id}:history"
        when 'admin'
          key = "searches:admin:#{user_id}:history"
        when 'sales'
          key = "searches:sales:#{user_id}:history"
        else
          return []
        end

        redis.zrevrange(key, 0, limit - 1, with_scores: true).map do |term, score|
          {
            search_term: term,
            timestamp: Time.at(score.to_i)
          }
        end
      end
    end

    # @param buyer_id [String] buyer UUID
    # @param limit [Integer] number of recent searches to return
    def recent_searches_for_buyer(buyer_id, limit = 10)
      recent_searches_for_user(buyer_id, 'buyer', limit)
    end

    # @param device_hash [String] device hash identifier
    # @param limit [Integer] number of recent searches to return
    def recent_searches_for_guest(device_hash, limit = 10)
      return [] if device_hash.blank?

      RedisConnection.with do |redis|
        key = "searches:guest:#{device_hash}:history"
        redis.zrevrange(key, 0, limit - 1, with_scores: true).map do |term, score|
          {
            search_term: term,
            timestamp: Time.at(score.to_i)
          }
        end
      end
    end

    # @param user_id [String, nil] user UUID if authenticated, nil for guests
    # @param role [String, nil] user role (buyer, seller, admin, sales, guest)
    # @param device_hash [String, nil] device hash for guest users
    # @param limit [Integer] number of recent searches to return
    def recent_searches_for_current_user(user_id: nil, role: nil, device_hash: nil, limit: 10)
      if user_id.present? && role.present? && role != 'guest'
        return recent_searches_for_user(user_id, role, limit)
      end

      if device_hash.present?
        return recent_searches_for_guest(device_hash, limit)
      end

      []
    end

    # @param page [Integer] page number (1-based)
    # @param per_page [Integer] records per page
    # @param filters [Hash] optional filters (user_id, buyer_id, seller_id, role, search_term, date_range)
    def search_history(page: 1, per_page: 50, filters: {})
      RedisConnection.with do |redis|
        all_keys = redis.keys("searches:search:*")
        filtered_keys = apply_filters(all_keys, filters, redis)

        sorted_keys = filtered_keys.sort_by { |key| redis.hget(key, 'timestamp').to_i }.reverse
        start_index = (page - 1) * per_page
        paginated_keys = sorted_keys[start_index, per_page] || []
        total_count = filtered_keys.size

        searches = paginated_keys.map do |key|
          data = redis.hgetall(key)
          next if data.empty?

          {
            id: key.split(':').last,
            search_term: data['search_term'],
            user_id: data['user_id'].present? ? data['user_id'] : nil,
            buyer_id: data['user_id'].present? && data['role'] == 'buyer' ? data['user_id'] : nil,
            seller_id: data['user_id'].present? && data['role'] == 'seller' ? data['user_id'] : nil,
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

    def cleanup_expired_data
      RedisConnection.with do |redis|
        Rails.logger.info "Redis search cleanup completed (no expiration configured)"
      end
    end

    private

    def generate_search_key(timestamp, user_id, role = nil)
      user_identifier = if user_id.present? && role.present?
        "#{role}:#{user_id}"
      elsif user_id.present?
        user_id
      else
        'guest'
      end
      "searches:search:#{timestamp}:#{user_identifier}:#{SecureRandom.hex(4)}"
    end

    def duplicate_search_recently?(search_term, user_id, session_id, device_hash)
      return false if session_id == 'unknown'

      RedisConnection.with do |redis|
        session_key = "searches:session:#{session_id}:recent"
        recent_searches = redis.zrangebyscore(session_key, Time.current.to_i - 30, Time.current.to_i, with_scores: true)
        recent_searches.any? { |term, timestamp| term == search_term && (Time.current.to_i - timestamp.to_i) < 30 }
      end
    rescue => e
      Rails.logger.warn "Error checking for duplicate search: #{e.message}"
      false
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

        if filters[:user_id].present?
          matches &= (data['user_id'] == filters[:user_id])
        end

        if filters[:buyer_id].present?
          matches &= (data['user_id'] == filters[:buyer_id] && data['role'] == 'buyer')
        end

        if filters[:seller_id].present?
          matches &= (data['user_id'] == filters[:seller_id] && data['role'] == 'seller')
        end

        if filters[:role].present?
          matches &= (data['role'] == filters[:role].to_s)
        end

        if filters[:device_hash].present?
          matches &= (data['device_hash'] == filters[:device_hash].to_s)
        end

        if filters[:exclude_roles].present?
          exclude_list = Array(filters[:exclude_roles]).map(&:to_s).map(&:downcase)
          matches &= !exclude_list.include?(data['role'].to_s.downcase)
        end

        if filters[:search_term].present?
          matches &= data['search_term'].to_s.downcase.include?(filters[:search_term].downcase)
        end

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