class ConnectionPoolMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Skip middleware for WebSocket connections (ActionCable)
    # Debug: Log the request details
    logger = Rails.logger || Logger.new(STDOUT)
    logger.info "ConnectionPoolMiddleware: PATH_INFO=#{env['PATH_INFO']}, HTTP_UPGRADE=#{env['HTTP_UPGRADE']}"
    
    if env['PATH_INFO'] == '/cable' || env['HTTP_UPGRADE'] == 'websocket'
      logger.info "Skipping middleware for WebSocket connection"
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
