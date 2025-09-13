class HealthController < ApplicationController
  def show
    health_status = {
      status: 'healthy',
      timestamp: Time.current.iso8601,
      services: {
        redis: redis_healthy?,
        database: database_healthy?
      }
    }

    if health_status[:services].values.all?
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end

  private

  def redis_healthy?
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")).ping == 'PONG'
  rescue StandardError
    false
  end

  def database_healthy?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end
end
