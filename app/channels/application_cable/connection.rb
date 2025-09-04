module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # Minimal connection setup
    def connect
      # Allow all connections for now
    end
    
    private
    
    def find_verified_user
      # For now, return nil to allow all connections
      nil
    end
  end
end
