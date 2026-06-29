class CallPersistJob < ApplicationJob
  queue_as :default

  def perform(call_sid)
    redis_key = "call_log:#{call_sid}"
    
    # Retrieve the high-speed log from Redis
    log_data = RedisConnection.hgetall(redis_key)
    
    return if log_data.empty?

    # Create the PostgreSQL record
    CallRecord.create!(
      call_sid: call_sid,
      caller_phone: 'agent', # It's an outgoing native call
      recipient_phone: log_data['to'],
      status: log_data['status'],
      duration: log_data['duration'].to_i,
      started_at: Time.at(log_data['updated_at'].to_i)
    )

    # Clean up Redis after successful persistence
    RedisConnection.del(redis_key)
  rescue StandardError => e
    Rails.logger.error "CallPersistJob Failed for #{call_sid}: #{e.message}"
  end
end
