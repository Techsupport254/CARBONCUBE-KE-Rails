# AnyCable configuration
AnyCable.configure do |config|
  # Use Redis for broadcasting
  config.broadcast_adapter = :redis
  config.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  
  # RPC server configuration
  config.rpc_host = "0.0.0.0:50051"
  
  # Logging
  config.log_level = :debug
  
  # Performance settings
  config.rpc_pool_size = 30
  config.rpc_pool_keep_alive = 30
end
