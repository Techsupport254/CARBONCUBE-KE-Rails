class ConnectionPoolMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Ensure connections are properly managed
    ActiveRecord::Base.connection_pool.with_connection do
      @app.call(env)
    end
  rescue ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error "Connection error: #{e.message}"
    [503, { 'Content-Type' => 'application/json' }, [{ error: 'Service temporarily unavailable' }.to_json]]
  end
end
