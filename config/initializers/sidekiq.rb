# Sidekiq configuration
require 'sidekiq'

# Configure Redis connection for Sidekiq
redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

# Configure Rails to use Redis
Rails.application.configure do
  config.active_job.queue_adapter = :sidekiq
  
  # Enable WebSocket functionality
  config.websocket_enabled = true
end
