class ProcessReadReceiptJob < ApplicationJob
  queue_as :websocket
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(message_id, reader_user_id)
    Rails.logger.info "Processing read receipt: message_id=#{message_id}, reader_id=#{reader_user_id}"
    
    begin
      message = Message.find(message_id)
      Rails.logger.info "Found message: #{message.id}"
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "Message not found: #{message_id}"
      return
    end
    
    # Find the reader - try buyer first, then seller, then admin
    reader = Buyer.find_by(id: reader_user_id) || Seller.find_by(id: reader_user_id) || Admin.find_by(id: reader_user_id)
    
    unless reader
      Rails.logger.warn "Reader not found: #{reader_user_id}"
      return
    end
    
    Rails.logger.info "Found reader: #{reader.class.name} ##{reader.id}"
    
    # Prevent reading own messages
    if message.sender_id == reader.id && message.sender_type == reader.class.name
      Rails.logger.info "Skipping read receipt for own message"
      return
    end
    
    # Update message read status
    message.update!(status: 'read', read_at: Time.current)
    Rails.logger.info "Updated message status to: #{message.status}"
    
    # Set Redis data
    read_key = "message_read:#{message.id}:#{reader.id}"
    read_data = {
      message_id: message.id,
      reader_id: reader.id,
      reader_type: reader.class.name,
      read_at: Time.current.iso8601
    }
    
    RedisConnection.setex(read_key, 86400 * 7, read_data.to_json)
    Rails.logger.info "Set Redis data"
    
    # Verify Redis
    retrieved = RedisConnection.get(read_key)
    Rails.logger.info "Retrieved from Redis: #{retrieved}"
    
    Rails.logger.info "Successfully processed read receipt for message #{message_id}"
    
  rescue StandardError => e
    Rails.logger.error "Failed to process read receipt: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end