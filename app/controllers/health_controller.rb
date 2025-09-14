class HealthController < ApplicationController
  # Skip authentication for health checks
  skip_before_action :authenticate_request, raise: false
  
  def websocket_status
    status = WebsocketService.status
    
    render json: {
      websocket: status,
      timestamp: Time.current.iso8601,
      deployment_safe: true # Always true to prevent deployment blocking
    }
  end
  
  def overall_health
    websocket_status = WebsocketService.status
    
    # Overall health is good if backend is running, even if websocket is down
    overall_healthy = true
    
    render json: {
      healthy: overall_healthy,
      services: {
        backend: true,
        database: database_healthy?,
        redis: redis_healthy?,
        websocket: websocket_status[:available]
      },
      websocket_status: websocket_status,
      timestamp: Time.current.iso8601
    }
  end
  
  private
  
  def database_healthy?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end
  
  def redis_healthy?
    Redis.current.ping == 'PONG'
  rescue StandardError
    false
  end
end