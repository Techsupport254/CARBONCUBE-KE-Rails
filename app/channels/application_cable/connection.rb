module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id
    
    def connect
      Rails.logger.info "🔌 WebSocket: CONNECT METHOD CALLED"
      
      @connection_id = SecureRandom.uuid
      self.session_id = SecureRandom.uuid
      
      Rails.logger.info "WebSocket: Simple connection attempt #{@connection_id} from #{request.remote_ip rescue 'unknown'}"
      
      # Simplified connection - allow all connections for now
      Rails.logger.info "🔌 WebSocket connection established (simplified mode)"
    end
    
    def disconnect
      Rails.logger.info "🔌 WebSocket connection closed (simplified mode)"
    end
  end
end