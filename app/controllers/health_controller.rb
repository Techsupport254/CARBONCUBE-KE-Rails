class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false
  
  def database
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    render json: {
      status: 'healthy',
      response_time: "#{response_time}ms",
      connection_pool: {
        size: ActiveRecord::Base.connection_pool.size,
        checked_out: ActiveRecord::Base.connection_pool.checked_out.size,
        available: ActiveRecord::Base.connection_pool.available_count,
        waiting: ActiveRecord::Base.connection_pool.num_waiting
      }
    }
  rescue => e
    render json: {
      status: 'unhealthy',
      error: e.message,
      response_time: ((Time.current - start_time) * 1000).round(2)
    }, status: 503
  end
  
  def redis
    start_time = Time.current
    Rails.cache.write("health_check", "ok", expires_in: 1.second)
    Rails.cache.read("health_check")
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    render json: {
      status: 'healthy',
      response_time: "#{response_time}ms"
    }
  rescue => e
    render json: {
      status: 'unhealthy',
      error: e.message,
      response_time: ((Time.current - start_time) * 1000).round(2)
    }, status: 503
  end
  
  def overall
    database_status = check_database
    redis_status = check_redis
    
    overall_status = database_status[:status] == 'healthy' && redis_status[:status] == 'healthy' ? 'healthy' : 'unhealthy'
    
    render json: {
      status: overall_status,
      database: database_status,
      redis: redis_status,
      timestamp: Time.current.iso8601
    }, status: overall_status == 'healthy' ? 200 : 503
  end
  
  private
  
  def check_database
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    {
      status: 'healthy',
      response_time: "#{response_time}ms"
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      response_time: ((Time.current - start_time) * 1000).round(2)
    }
  end
  
  def check_redis
    start_time = Time.current
    Rails.cache.write("health_check", "ok", expires_in: 1.second)
    Rails.cache.read("health_check")
    response_time = ((Time.current - start_time) * 1000).round(2)
    
    {
      status: 'healthy',
      response_time: "#{response_time}ms"
    }
  rescue => e
    {
      status: 'unhealthy',
      error: e.message,
      response_time: ((Time.current - start_time) * 1000).round(2)
    }
  end
end