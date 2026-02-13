# AnyCable configuration
# if Rails.env.production?
  # Configure AnyCable for production
  # AnyCable.configure do |config|
    # Use Redis as the pub/sub adapter
    # config.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
    
    # RPC server configuration
    # config.rpc_host = "0.0.0.0:50051"
    
    # Logging
    # config.log_level = :info
  # end
  
  # Configure Action Cable to use AnyCable
  # Rails.application.configure do
  #   config.action_cable.adapter = :any_cable
  # end
# end
