# Suppress ActionCable "Ignoring message processed after WebSocket was closed" warnings
# These are harmless and occur during normal client disconnect/reconnect cycles

Rails.application.config.after_initialize do
  if defined?(ActionCable)
    # Create a custom logger that filters out noisy ActionCable errors
    original_logger = Rails.logger
    
    ActionCable.server.config.logger = ActiveSupport::Logger.new(STDOUT).tap do |logger|
      logger.level = Logger::ERROR
      
      # Override the error method to filter out specific messages
      class << logger
        def error(message = nil, &block)
          return if message.to_s.include?("Ignoring message processed after the WebSocket was closed")
          return if message.to_s.include?("Could not execute command from") && message.to_s.include?("Unable to find subscription")
          super
        end
      end
    end
  end
end
