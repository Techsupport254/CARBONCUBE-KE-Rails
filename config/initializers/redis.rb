# Redis configuration for the application
REDIS_URL = ENV['REDIS_URL'] || 'redis://localhost:6379/0'

# Configure Redis connection - Redis 5.x doesn't have Redis.current
# We'll create a module to provide this functionality
module RedisConnection
  class << self
    def current
      @current ||= Redis.new(url: REDIS_URL)
    end
    
    def ping
      current.ping
    end
    
    def setex(key, ttl, value)
      current.setex(key, ttl, value)
    end
    
    def get(key)
      current.get(key)
    end
    
    def del(key)
      current.del(key)
    end
    
    def incrby(key, value)
      current.incrby(key, value)
    end
    
    def expire(key, ttl)
      current.expire(key, ttl)
    end
    
    def keys(pattern)
      current.keys(pattern)
    end
  end
end

# Test connection
begin
  RedisConnection.ping
  Rails.logger.info "Redis connection established successfully"
rescue => e
  Rails.logger.warn "Redis connection failed: #{e.message}"
end
