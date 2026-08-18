class UploadTelemetryRedisService
  LOG_LIST_KEY = 'telemetry:upload_logs'
  SUMMARY_KEY = 'telemetry:summary'
  MAX_LOG_ITEMS = 1000

  class << self
    def record(seller_id:, session_id:, data: {}, is_batch: false, batch_size: 1)
      return if seller_id.blank?

      timestamp = Time.current.to_i
      event_id = "tel_#{timestamp}_#{SecureRandom.hex(4)}"

      payload = {
        id: event_id,
        seller_id: seller_id.to_s,
        session_id: session_id.presence || SecureRandom.uuid,
        ad_id: data[:ad_id].to_s,
        is_batch: is_batch || data[:is_batch] || false,
        batch_size: (batch_size || data[:batch_size] || 1).to_i,
        product_index: (data[:product_index] || 1).to_i,
        was_offline: data[:was_offline] || false,
        time_to_first_interaction_ms: (data[:time_to_first_interaction_ms] || 0).to_f,
        total_user_dwell_time_sec: (data[:total_user_dwell_time_sec] || 0).to_f,
        field_dwell_breakdown: data[:field_dwell_breakdown] || {},
        image_count: (data[:image_count] || 0).to_i,
        client_compression_ms: (data[:client_compression_ms] || 0).to_f,
        network_transit_ms: (data[:network_transit_ms] || 0).to_f,
        server_processing_ms: (data[:server_processing_ms] || 0).to_f,
        total_system_latency_ms: (data[:total_system_latency_ms] || 0).to_f,
        timestamp: timestamp,
        created_at: Time.current.iso8601
      }

      RedisConnection.with do |redis|
        # 1. Push payload to rolling list of recent upload events
        redis.lpush(LOG_LIST_KEY, payload.to_json)
        redis.ltrim(LOG_LIST_KEY, 0, MAX_LOG_ITEMS - 1)

        # 2. Push to seller-specific telemetry list
        seller_key = "telemetry:seller:#{seller_id}:logs"
        redis.lpush(seller_key, payload.to_json)
        redis.ltrim(seller_key, 0, 200)

        # 3. Update global Redis atomic summary metrics
        redis.hincrby(SUMMARY_KEY, 'total_uploads', 1)
        redis.hincrbyfloat(SUMMARY_KEY, 'total_dwell_sec', payload[:total_user_dwell_time_sec])
        redis.hincrbyfloat(SUMMARY_KEY, 'total_latency_ms', payload[:total_system_latency_ms])
        redis.hincrbyfloat(SUMMARY_KEY, 'total_server_processing_ms', payload[:server_processing_ms])
        redis.hincrby(SUMMARY_KEY, 'batch_count', 1) if payload[:is_batch]
        redis.hincrby(SUMMARY_KEY, 'offline_count', 1) if payload[:was_offline]
      end

      payload
    rescue => e
      Rails.logger.warn "[UploadTelemetryRedisService] Redis write error: #{e.message}"
      nil
    end

    def summary_stats(seller_id: nil)
      RedisConnection.with do |redis|
        if seller_id.present?
          seller_key = "telemetry:seller:#{seller_id}:logs"
          logs_json = redis.lrange(seller_key, 0, -1)
          logs = logs_json.map { |j| JSON.parse(j) rescue nil }.compact

          total = logs.length
          return { total_uploads: 0, avg_dwell_time_sec: 0, avg_system_latency_ms: 0, offline_count: 0, batch_count: 0 } if total.zero?

          sum_dwell = logs.sum { |l| l['total_user_dwell_time_sec'].to_f }
          sum_lat = logs.sum { |l| l['total_system_latency_ms'].to_f }
          sum_proc = logs.sum { |l| l['server_processing_ms'].to_f }

          {
            total_uploads: total,
            avg_dwell_time_sec: (sum_dwell / total).round(2),
            avg_system_latency_ms: (sum_lat / total).round(2),
            avg_server_processing_ms: (sum_proc / total).round(2),
            offline_count: logs.count { |l| l['was_offline'] },
            batch_count: logs.count { |l| l['is_batch'] }
          }
        else
          stats = redis.hgetall(SUMMARY_KEY) || {}
          total = (stats['total_uploads'] || 0).to_i
          return { total_uploads: 0, avg_dwell_time_sec: 0, avg_system_latency_ms: 0, offline_count: 0, batch_count: 0 } if total.zero?

          dwell = (stats['total_dwell_sec'] || 0).to_f
          lat = (stats['total_latency_ms'] || 0).to_f
          proc_time = (stats['total_server_processing_ms'] || 0).to_f

          {
            total_uploads: total,
            avg_dwell_time_sec: (dwell / total).round(2),
            avg_system_latency_ms: (lat / total).round(2),
            avg_server_processing_ms: (proc_time / total).round(2),
            offline_count: (stats['offline_count'] || 0).to_i,
            batch_count: (stats['batch_count'] || 0).to_i
          }
        end
      end
    rescue => e
      Rails.logger.warn "[UploadTelemetryRedisService] Redis read error: #{e.message}"
      { total_uploads: 0, avg_dwell_time_sec: 0, avg_system_latency_ms: 0, offline_count: 0, batch_count: 0 }
    end

    def recent_logs(limit = 50)
      RedisConnection.with do |redis|
        logs_json = redis.lrange(LOG_LIST_KEY, 0, limit - 1)
        logs_json.map { |j| JSON.parse(j) rescue nil }.compact
      end
    rescue => e
      Rails.logger.warn "[UploadTelemetryRedisService] Error fetching recent logs: #{e.message}"
      []
    end
  end
end
