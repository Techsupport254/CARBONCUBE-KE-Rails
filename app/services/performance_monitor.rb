# Performance Monitor Service
# Tracks and logs performance metrics for optimization
class PerformanceMonitor
  include ActiveSupport::Benchmarkable

  class << self
    # Track database query performance
    def track_query_performance(query_name, &block)
      start_time = Time.current
      result = yield
      duration = (Time.current - start_time) * 1000 # Convert to milliseconds
      
      Rails.logger.info "PERFORMANCE: #{query_name} took #{duration.round(2)}ms"
      
      # Log slow queries
      if duration > 100 # Log queries taking more than 100ms
        Rails.logger.warn "SLOW QUERY: #{query_name} took #{duration.round(2)}ms"
      end
      
      result
    end

    # Track API response performance
    def track_api_performance(endpoint, &block)
      start_time = Time.current
      result = yield
      duration = (Time.current - start_time) * 1000
      
      Rails.logger.info "API PERFORMANCE: #{endpoint} took #{duration.round(2)}ms"
      
      # Log slow API responses
      if duration > 500 # Log API responses taking more than 500ms
        Rails.logger.warn "SLOW API: #{endpoint} took #{duration.round(2)}ms"
      end
      
      result
    end

    # Track cache hit rates
    def track_cache_performance(cache_key, hit: true)
      if hit
        Rails.logger.info "CACHE HIT: #{cache_key}"
      else
        Rails.logger.info "CACHE MISS: #{cache_key}"
      end
    end

    # Get performance summary
    def performance_summary
      {
        database_queries: database_query_stats,
        api_responses: api_response_stats,
        cache_performance: cache_performance_stats
      }
    end

    private

    def database_query_stats
      # This would typically come from a monitoring service
      # For now, return basic stats
      {
        total_queries: 0,
        average_time: 0,
        slow_queries: 0
      }
    end

    def api_response_stats
      {
        total_requests: 0,
        average_response_time: 0,
        slow_responses: 0
      }
    end

    def cache_performance_stats
      {
        hit_rate: 0,
        miss_rate: 0,
        total_requests: 0
      }
    end
  end
end
