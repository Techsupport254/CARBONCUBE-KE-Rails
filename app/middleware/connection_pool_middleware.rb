class ConnectionPoolMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Skip middleware for WebSocket connections (ActionCable)
    if env['PATH_INFO'] == '/cable' || env['HTTP_UPGRADE'] == 'websocket'
      return @app.call(env)
    end
    
    # Ensure connections are properly managed for regular HTTP requests
    ActiveRecord::Base.connection_pool.with_connection do
      @app.call(env)
    end
  rescue ActiveRecord::ConnectionNotEstablished => e
    # Use a safe logger that won't fail if Rails.logger is nil
    logger = Rails.logger || Logger.new(STDOUT)
    logger.error "Connection error: #{e.message}"
    [503, { 'Content-Type' => 'application/json' }, [{ error: 'Service temporarily unavailable' }.to_json]]
  end
end
