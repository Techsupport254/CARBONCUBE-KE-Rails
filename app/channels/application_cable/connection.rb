module ApplicationCable
  class Connection < ActionCable::Connection::Base
    def connect
      # Allow all connections for now, but log connection attempts
      Rails.logger.info "🔌 WebSocket connection established from #{request.remote_ip}"
      
      # Set connection timeout to prevent hanging connections
      @connection_timeout = 60.seconds # Increased timeout
      
      # Start a timer to close idle connections (less aggressive)
      @idle_timer = Concurrent::TimerTask.new(execution_interval: 60) do
        if @last_activity && @last_activity < 60.seconds.ago
          Rails.logger.info "⏰ Closing idle WebSocket connection from #{request.remote_ip}"
          close
        end
      end
      @idle_timer.execute
    end
    
    def disconnect
      Rails.logger.info "🔌 WebSocket connection closed from #{request.remote_ip}"
      
      # Clean up timer
      @idle_timer&.shutdown
    end
    
    def receive(data)
      # Update last activity timestamp
      @last_activity = Time.current
      super
    rescue => e
      Rails.logger.warn "WebSocket receive error: #{e.message}"
      # Don't re-raise to prevent connection drops
    end
    
    private
    
    def find_verified_user
      # For now, return nil to allow all connections
      nil
    end
  end
end
