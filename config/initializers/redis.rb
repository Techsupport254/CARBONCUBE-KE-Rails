# Redis configuration for the application
# DB 0: Cache store
# DB 1: Session store
REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
REDIS_SESSION_URL = ENV['REDIS_SESSION_URL'] || 'redis://localhost:6379/1'

# Configure Redis connection pool for better performance
# Redis 5.x uses redis-client which has simpler configuration
module RedisConnection
  class << self
    def pool
      @pool ||= ConnectionPool.new(size: 10, timeout: 5) do
        Redis.new(url: REDIS_URL, timeout: 5)
      end
    end

    def current
      @current ||= Redis.new(url: REDIS_URL, timeout: 5)
    end

    def with
      pool.with { |conn| yield conn }
    end

    def ping
      current.ping
    end

    def setex(key, ttl, value)
      with { |conn| conn.setex(key, ttl, value) }
    end

    def get(key)
      with { |conn| conn.get(key) }
    end

    def del(key)
      with { |conn| conn.del(key) }
    end

    def incrby(key, value)
      with { |conn| conn.incrby(key, value) }
    end

    def expire(key, ttl)
      with { |conn| conn.expire(key, ttl) }
    end

    def exists?(key)
      with { |conn| conn.exists?(key) }
    end

    def keys(pattern)
      with { |conn| conn.keys(pattern) }
    end
  end
end

# Lazily initialize Redis connection pool at startup.
# Avoid eager connections so the Rails/Puma process boots even when Redis is
# temporarily unreachable. Real Redis failures will surface when the app actually
# uses Redis (Action Cable, Sidekiq, cache store, etc.).
begin
  RedisConnection.ping
  Rails.logger.info "Redis is reachable at boot"
rescue => e
  Rails.logger.warn "Redis not reachable at boot (#{e.message}). Connection will be retried on first use."
end
