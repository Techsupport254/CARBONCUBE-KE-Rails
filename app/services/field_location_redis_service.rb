# Redis service for storing hourly field location pings during the work day.
#
# Pattern: Redis accumulates pings throughout the day (8am-4pm).
# SyncFieldLocationsJob flushes them to Postgres at 5pm EAT as a single
# row per user per day with a JSONB array of pings.
#
# Redis key format:
#   sales_field_location:{user_id}:{YYYY-MM-DD}
#
# Each key holds a JSON array of ping objects:
#   [{ ts, lat, lng, display_name, area, city, county, country }, ...]
#
# Keys expire after 2 days (TTL) so stale data is auto-cleaned if the
# flush job fails.
class FieldLocationRedisService
  KEY_PREFIX = 'sales_field_location'.freeze
  TTL = 2.days.to_i
  WORK_START_HOUR = 8  # 8 AM EAT
  WORK_END_HOUR = 16   # 4 PM EAT
  EAT_TIMEZONE = 'Africa/Nairobi'.freeze

  class << self
    # Current date in Nairobi time (EAT, UTC+3).
    # The server runs in UTC, so Date.current returns the UTC date which is
    # wrong for EAT-based logic (e.g. at 11 PM EAT it would still show the
    # previous day's date in UTC).
    #
    # @return [Date]
    def eat_today
      Time.current.in_time_zone(EAT_TIMEZONE).to_date
    end

    # Current time in Nairobi (EAT).
    #
    # @return [Time]
    def eat_now
      Time.current.in_time_zone(EAT_TIMEZONE)
    end
    # Append a ping to the user's daily list in Redis.
    # Returns true if the ping was accepted, false if outside work hours
    # or a holiday.
    #
    # @param user_id [String] the sales user UUID
    # @param ping [Hash] { lat:, lng:, display_name:, area:, city:, county:, country: }
    # @return [Boolean]
    # Returns true if the ping was accepted, false if outside work hours,
    # a duplicate for this hour, or invalid data. Has side effects (writes to Redis).
    # rubocop:disable Naming/PredicateMethod
    def add_ping(user_id, ping)
      return false unless ping_valid?(ping)

      key = daily_key(user_id)
      pings = fetch_pings(user_id)

      # Avoid duplicate pings within the same hour (EAT)
      hour_key = eat_now.hour
      return false if pings.any? { |p| p['hour'] == hour_key }

      entry = ping.merge(
        'ts' => Time.current.iso8601,
        'hour' => hour_key
      )

      RedisConnection.with do |conn|
        conn.multi do |pipeline|
          pings << entry
          pipeline.set(key, JSON.generate(pings))
          pipeline.expire(key, TTL)
        end
      end

      true
    end
    # rubocop:enable Naming/PredicateMethod

    # Fetch all pings for a user on a given date.
    #
    # @param user_id [String]
    # @param date [Date, String] defaults to today
    # @return [Array<Hash>]
    def fetch_pings(user_id, date = eat_today)
      key = daily_key(user_id, date)
      raw = RedisConnection.get(key)
      return [] unless raw

      JSON.parse(raw)
    rescue JSON::ParserError
      []
    end

    # Fetch all pending daily keys (for the flush job).
    # Returns array of { user_id:, date:, key: }.
    #
    # @param date [Date, String] defaults to today
    # @return [Array<Hash>]
    def pending_keys(date = eat_today)
      date_str = date.to_s
      pattern = "#{KEY_PREFIX}:*:{date_str}"

      RedisConnection.keys(pattern).filter_map do |key|
        parts = key.to_s.split(':')
        next unless parts.length == 3

        { user_id: parts[1], date: date_str, key: key }
      end
    end

    # Delete a user's daily key after a successful flush.
    #
    # @param key [String]
    def delete_key(key)
      RedisConnection.del(key)
    end

    # Check if a ping is within work hours (8am-4pm EAT, UTC+3) and on a
    # working day (Mon–Fri — not weekends).
    # The controller already checks holidays; this is a secondary guard.
    #
    # @param ping [Hash]
    # @return [Boolean]
    def ping_valid?(ping)
      return false unless ping[:lat] && ping[:lng]

      now = eat_now
      return false unless now.hour.between?(WORK_START_HOUR, WORK_END_HOUR)

      # 0=Sunday, 6=Saturday
      day = now.wday
      day != 0 && day != 6
    end

    private

    def daily_key(user_id, date = eat_today)
      date_str = date.is_a?(Date) ? date.iso8601 : Date.parse(date.to_s).iso8601
      "#{KEY_PREFIX}:#{user_id}:#{date_str}"
    end
  end
end
