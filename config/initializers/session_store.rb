# Redis session store configuration
# Stores sessions in Redis for better scalability and server-side session management
# Benefits:
# - Shared sessions across multiple app servers (required for horizontal scaling)
# - No 4KB cookie size limit
# - Server-side session invalidation (force logout users)
# - Automatic expiration via Redis TTL

# Use REDIS_URL but specify DB 1 for sessions (separate from cache in DB 0)
redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
# Replace database number to use DB 1 for sessions
session_redis_url = redis_url.sub(/\/\d+$/, '/1')

Rails.application.config.session_store :redis_store,
  servers: [session_redis_url],
  expire_after: 4.hours,  # Session expiration time
  key: '_app_session',
  threadsafe: true,
  secure: Rails.env.production?,  # Use secure cookies in production
  httponly: true,  # Prevent JavaScript access to session cookie
  same_site: :lax,  # CSRF protection with reasonable cross-origin behavior
  redis: {
    connect_timeout: 1,  # 1 second timeout for connection
    read_timeout: 0.2,   # 200ms timeout for reads
    write_timeout: 0.2    # 200ms timeout for writes
  }
