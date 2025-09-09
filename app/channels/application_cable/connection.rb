module ApplicationCable
  class Connection < ActionCable::Connection::Base
    def connect
      # Allow all connections for now, but log connection attempts
      Rails.logger.info "🔌 WebSocket connection established from #{request.remote_ip}"
    end
    
    def disconnect
      Rails.logger.info "🔌 WebSocket connection closed from #{request.remote_ip}"
    end
    
    private
    
    def find_verified_user
      # For now, return nil to allow all connections
      nil
    end
  end
end
