# Suppress ActionCable logging in development
if Rails.env.development?
  ActionCable.server.config.logger = nil
  ActionCable.server.config.log_tags = []
  
  # Also suppress WebSocket connection logs
  Rails.logger.level = Logger::ERROR if Rails.logger
end
