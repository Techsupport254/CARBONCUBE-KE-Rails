# Redis configuration for the application
REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost:6379/0'

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

# Eagerly initialize Redis connection pool at startup
begin
  # Initialize the pool
  RedisConnection.pool
  # Test connection
  RedisConnection.ping
  Rails.logger.info "✅ Redis connection pool initialized successfully"
rescue => e
  Rails.logger.error "❌ Redis connection failed: #{e.message}"
  Rails.logger.error "Please ensure Redis is running: redis-server"
end
