class CallPersistJob < ApplicationJob
  queue_as :default

  def perform(call_sid)
    redis_key = "call_log:#{call_sid}"
    
    # Retrieve the high-speed log from Redis
    RedisConnection.with do |conn|
      log_data = conn.hgetall(redis_key)
      
      Rails.logger.info "CallPersistJob: Processing call_sid=#{call_sid}"
      Rails.logger.info "CallPersistJob: log_data keys=#{log_data.keys.inspect}"
      Rails.logger.info "CallPersistJob: customer_email=#{log_data['customer_email'].inspect}"
      
      return if log_data.empty?

      status = log_data['status']
      status = 'abandoned' unless CallRecord.statuses.key?(status)

      call_type = log_data['call_type']
      call_type = 'outbound' unless CallRecord.call_types.key?(call_type)

      # Find customer (Seller first, then Buyer)
      customer = nil
      if log_data['customer_email'].present?
        customer = Seller.find_by(email: log_data['customer_email']) || Buyer.find_by(email: log_data['customer_email'])
      end

      if customer.nil? && log_data['to'].present?
        # Normalize phone number to match format in db
        phone = log_data['to'].gsub(/\D/, '')
        if phone.length >= 9
          # Search using suffix matching
          suffix = phone[-9..-1]
          customer = Seller.where("phone_number LIKE ?", "%#{suffix}").first || Buyer.where("phone_number LIKE ?", "%#{suffix}").first
        else
          customer = Seller.find_by(phone_number: log_data['to']) || Buyer.find_by(phone_number: log_data['to'])
        end
      end

      # Create the PostgreSQL record with enhanced fields
      call_record = CallRecord.new(
        status: status,
        duration_seconds: log_data['duration'].to_i,
        started_at: Time.at(log_data['updated_at'].to_i),
        call_type: call_type,
        caller_name: log_data['caller_name'],
        caller_phone: log_data['to'],
        customer_email: log_data['customer_email'],
        sales_user_id: log_data['sales_user_id'],
        call_reason: log_data['call_reason'],
        issue_category: log_data['issue_category'],
        disposition: log_data['disposition'],
        issue_resolved: log_data['issue_resolved'] == 'true',
        agent_notes: log_data['agent_notes'],
        follow_up_required: log_data['follow_up_required'] == 'true',
        follow_up_date: log_data['follow_up_date'],
        follow_up_action: log_data['follow_up_action']
      )

      call_record.customer = customer if customer.present?
      call_record.save!

      # Queue logic: if this is a Seller, resolve all pending queue entries for them
      if customer.present? && customer.is_a?(Seller)
        CallQueue.where(seller_id: customer.id, status: CallQueue::STATUS_PENDING).find_each do |queue_item|
          queue_item.start!
          queue_item.resolve!(log_data['sales_user_id'])
        end
      end

      # Log this action to the activity stream so it appears in the UI
      activity = {
        id: call_sid,
        action: "Call Logged",
        user: call_record.sales_user&.fullname || "Agent",
        timestamp: Time.current.iso8601,
        details: "#{log_data['call_type']&.capitalize || 'Outbound'} call to #{log_data['caller_name'] || log_data['to']}"
      }
      conn.lpush('call_center:activity_logs', activity.to_json)
      conn.ltrim('call_center:activity_logs', 0, 999)

      Rails.logger.info "CallPersistJob: Created call_record id=#{call_record.id}, rating_token=#{call_record.rating_token}"

      # Send email summary if customer email is provided
      if log_data['customer_email'].present?
        Rails.logger.info "CallPersistJob: Sending email to #{log_data['customer_email']}"
        send_call_summary_email(call_record, log_data)
      else
        Rails.logger.info "CallPersistJob: No customer email provided, skipping email"
      end

      # Clean up Redis after successful persistence
      conn.del(redis_key)
    end
  rescue StandardError => e
    Rails.logger.error "CallPersistJob Failed for #{call_sid}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def send_call_summary_email(call_record, log_data)
    # Generate rating link with UTMs
    frontend_url = ENV['FRONTEND_URL'] || 'https://calls.carboncube-ke.com'
    rating_link = "#{frontend_url}/rate-call/#{call_record.rating_token}?utm_source=email&utm_medium=call_summary&utm_campaign=call_rating"

    # Send email using nodemailer or your existing email system
    # This is a placeholder - implement based on your email system
    CallSummaryMailer.with(
      customer_name: log_data['caller_name'] || 'Customer',
      agent_name: call_record.sales_user&.fullname || 'Support Team',
      call_type: log_data['call_type']&.capitalize || 'Call',
      duration: format_duration(log_data['duration'].to_i),
      call_reason: log_data['call_reason'] || 'General inquiry',
      agent_notes: log_data['agent_notes'] || 'No notes provided',
      rating_link: rating_link,
      customer_email: log_data['customer_email']
    ).call_summary_email.deliver_later
  rescue StandardError => e
    Rails.logger.error "Failed to send call summary email: #{e.message}"
  end

  def format_duration(seconds)
    return "00:00" unless seconds && seconds > 0
    minutes = seconds / 60
    remaining_seconds = seconds % 60
    format("%02d:%02d", minutes, remaining_seconds)
  end
end
