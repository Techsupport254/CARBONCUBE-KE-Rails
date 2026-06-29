# frozen_string_literal: true

module Sales
  class CallCenterController < ApplicationController
    before_action :authenticate_user

    skip_before_action :verify_authenticity_token, only: [:log_call, :queue, :send_email], raise: false
    skip_before_action :authenticate_user, only: [:log_call, :queue, :send_email]

    # GET /sales/call_center/kpis
    def kpis
      cached_data = RedisConnection.get('call_center:kpis')
      
      if cached_data.present?
        render json: JSON.parse(cached_data)
      else
        # Fallback if job hasn't run or redis fails
        # Enqueue the job immediately to get data for next time
        CallCenterMetricsJob.perform_later
        
        render json: {
          queue_count: CallRecord.where(status: :pending).count,
          call_queue_count: CallQueue.pending.count,
          avg_handling_time_seconds: 0,
          handled_count: 0,
          handled_trend: 0,
          csat_score: 100
        }
      end
    end

    # GET /sales/call_center/chart_data
    def chart_data
      period = params[:period].presence || '7d'
      
      cached_data = RedisConnection.get("call_center:chart_data:#{period}")
      
      if cached_data.present?
        render json: JSON.parse(cached_data)
      else
        CallCenterMetricsJob.perform_later
        render json: []
      end
    end

    # GET /sales/call_center/history
    def history
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 10).to_i
      
      records = CallRecord.includes(:customer, :sales_user).order(started_at: :desc)
      
      if params[:search].present?
        term = "%#{params[:search].downcase}%"
        # Since joining polymorphic is complex and we want all users (buyers, sellers)
        # We can search the explicit caller_name/phone, or do a left outer join to buyers and sellers
        records = records.joins("LEFT OUTER JOIN buyers ON call_records.customer_id = buyers.id AND call_records.customer_type = 'Buyer'")
                         .joins("LEFT OUTER JOIN sellers ON call_records.customer_id = sellers.id AND call_records.customer_type = 'Seller'")
                         .where("LOWER(call_records.caller_name) LIKE ? OR call_records.caller_phone LIKE ? OR LOWER(buyers.fullname) LIKE ? OR LOWER(buyers.email) LIKE ? OR LOWER(sellers.fullname) LIKE ? OR LOWER(sellers.email) LIKE ?", term, term, term, term, term, term)
      end
      
      total_count = records.count
      paginated_records = records.offset((page - 1) * per_page).limit(per_page)

      history_data = paginated_records.map do |record|
        if record.customer
          customer_name = record.customer.try(:fullname) || record.customer.try(:email) || 'Unknown Customer'
          phone_number = record.customer.try(:phone_number) || record.customer.try(:phone) || record.caller_phone || 'N/A'
        else
          customer_name = record.caller_name.presence || 'Unknown Caller'
          phone_number = record.caller_phone.presence || 'N/A'
        end
        
        {
          id: "CALL-#{record.id.to_s.split('-').first.upcase}",
          customerName: customer_name,
          phoneNumber: phone_number,
          duration: format_duration(record.duration_seconds),
          status: record.status.capitalize,
          type: record.call_type.capitalize,
          agent: record.sales_user_id == current_user&.id ? 'You' : (record.sales_user.try(:fullname) || 'Unassigned'),
          started_at: record.started_at
        }
      end

      render json: {
        calls: history_data,
        total_pages: (total_count.to_f / per_page).ceil,
        current_page: page,
        total_count: total_count
      }
    end

    # GET /sales/call_center/history
    def history
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 10).to_i
      
      records = CallRecord.includes(:customer, :sales_user).order(started_at: :desc)
      
      if params[:search].present?
        term = "%#{params[:search].downcase}%"
        records = records.joins("LEFT OUTER JOIN buyers ON call_records.customer_id = buyers.id AND call_records.customer_type = 'Buyer'")
                         .joins("LEFT OUTER JOIN sellers ON call_records.customer_id = sellers.id AND call_records.customer_type = 'Seller'")
                         .where("LOWER(call_records.caller_name) LIKE ? OR call_records.caller_phone LIKE ? OR LOWER(buyers.fullname) LIKE ? OR LOWER(buyers.email) LIKE ? OR LOWER(sellers.fullname) LIKE ? OR LOWER(sellers.email) LIKE ?", term, term, term, term, term, term)
      end
      
      total_count = records.count
      paginated_records = records.offset((page - 1) * per_page).limit(per_page)

      history_data = paginated_records.map do |record|
        if record.customer
          customer_name = record.customer.try(:fullname) || record.customer.try(:email) || 'Unknown Customer'
          phone_number = record.customer.try(:phone_number) || record.customer.try(:phone) || record.caller_phone || 'N/A'
          avatar = record.customer.try(:profile_picture)
        else
          customer_name = record.caller_name.presence || 'Unknown Caller'
          phone_number = record.caller_phone.presence || 'N/A'
          avatar = nil
        end
        
        {
          id: "CALL-#{record.id.to_s.split('-').first.upcase}",
          customerName: customer_name,
          phoneNumber: phone_number,
          duration: format_duration(record.duration_seconds),
          status: record.status.capitalize,
          type: record.call_type.capitalize,
          agent: record.sales_user_id == current_user&.id ? 'You' : (record.sales_user.try(:fullname) || 'Unassigned'),
          started_at: record.started_at,
          avatar: avatar
        }
      end

      render json: {
        calls: history_data,
        total_pages: (total_count.to_f / per_page).ceil,
        current_page: page,
        total_count: total_count
      }
    end

    # GET /sales/call_center/logs
    def logs
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 50).to_i
      search = params[:search].to_s.downcase
      
      total_count = RedisConnection.with { |conn| conn.llen('call_center:activity_logs') } || 0
      
      start_index = (page - 1) * per_page
      end_index = start_index + per_page - 1
      
      raw_logs = RedisConnection.with { |conn| conn.lrange('call_center:activity_logs', start_index, end_index) } || []
      
      logs_data = raw_logs.filter_map do |log_json|
        begin
          JSON.parse(log_json)
        rescue JSON::ParserError
          nil
        end
      end
      
      if search.present?
        logs_data = logs_data.select do |log|
          log['action'].to_s.downcase.include?(search) ||
          log['user'].to_s.downcase.include?(search) ||
          log['details'].to_s.downcase.include?(search)
        end
        total_count = logs_data.length
      end

      render json: {
        logs: logs_data,
        total_pages: [(total_count.to_f / per_page).ceil, 1].max,
        current_page: page,
        total_count: total_count
      }
    end

    # POST /sales/call_center/log_call
    def log_call
      customer_name = params[:customerName]
      customer_phone = params[:phoneNumber]
      duration = params[:duration].to_i
      status = params[:status] # e.g. 'completed', 'missed', 'failed'
      
      # Enhanced call log fields
      call_type = params[:callType] || 'outbound'
      call_reason = params[:callReason]
      issue_category = params[:issueCategory]
      disposition = params[:disposition]
      issue_resolved = params[:issueResolved] == 'true'
      customer_satisfaction = params[:customerSatisfaction].to_i
      agent_notes = params[:agentNotes]
      follow_up_required = params[:followUpRequired] == 'true'
      follow_up_date = params[:followUpDate]
      follow_up_action = params[:followUpAction]
      
      call_sid = "native_#{SecureRandom.uuid}"
      redis_key = "call_log:#{call_sid}"

      # Cache the manual log briefly in Redis to reuse the high-speed pipeline
      RedisConnection.with do |conn|
        conn.hset(redis_key, "status", status)
        conn.hset(redis_key, "to", customer_phone)
        conn.hset(redis_key, "duration", duration)
        conn.hset(redis_key, "updated_at", Time.current.to_i)
        
        # Enhanced fields
        conn.hset(redis_key, "call_type", call_type)
        conn.hset(redis_key, "call_reason", call_reason) if call_reason.present?
        conn.hset(redis_key, "issue_category", issue_category) if issue_category.present?
        conn.hset(redis_key, "disposition", disposition) if disposition.present?
        conn.hset(redis_key, "issue_resolved", issue_resolved)
        conn.hset(redis_key, "customer_satisfaction", customer_satisfaction) if customer_satisfaction > 0
        conn.hset(redis_key, "agent_notes", agent_notes) if agent_notes.present?
        conn.hset(redis_key, "follow_up_required", follow_up_required)
        conn.hset(redis_key, "follow_up_date", follow_up_date) if follow_up_date.present?
        conn.hset(redis_key, "follow_up_action", follow_up_action) if follow_up_action.present?
        
        conn.expire(redis_key, 3600)
      end

      # Fire the background job to persist
      CallPersistJob.perform_later(call_sid)

      render json: { success: true, call_sid: call_sid }
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # GET /sales/call_center/queue
    def queue
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 50).to_i
      queue_type = params[:queue_type].presence
      priority = params[:priority].presence
      search = params[:search].presence

      queue_data = CallQueueService.get_queue_data(page: page, per_page: per_page, queue_type: queue_type, priority: priority, search: search)

      render json: queue_data
    end

    # GET /sales/call_center/queue_types
    def queue_types
      # Get all queue types with their current counts and priorities
      queue_stats = CallQueue.pending.group(:queue_type).count
      
      # Calculate weighted priority for each type
      queue_types_data = CallQueue::QUEUE_TYPES.map do |type_const, display_name|
        count = queue_stats[type_const] || 0
        priority = CallQueueService.get_priority_for_type(type_const)
        
        # Calculate weighted score: count * priority
        weighted_score = count * priority
        
        {
          type: type_const,
          display: display_name,
          priority: priority,
          count: count,
          weighted_score: weighted_score
        }
      end
      
      # Sort by weighted score (highest first)
      sorted_types = queue_types_data.sort_by { |t| -t[:weighted_score] }
      
      render json: { queue_types: sorted_types }
    end

    # POST /sales/call_center/:id/resolve
    def resolve
      queue_item = CallQueue.find(params[:id])
      
      if queue_item.status == CallQueue::STATUS_RESOLVED
        render json: { error: 'Queue item already resolved' }, status: :bad_request
        return
      end

      queue_item.resolve!(current_user&.id)

      render json: { success: true, message: 'Queue item resolved' }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Queue item not found' }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /sales/call_center/:id/start
    def start
      queue_item = CallQueue.find(params[:id])
      
      if queue_item.status != CallQueue::STATUS_PENDING
        render json: { error: 'Queue item is not pending' }, status: :bad_request
        return
      end

      queue_item.start!

      render json: { success: true, message: 'Queue item started' }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Queue item not found' }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /sales/call_center/:id/send_email
    def send_email
      queue_item = CallQueue.find(params[:id])
      subject = params[:subject]
      message = params[:message]

      if subject.blank? || message.blank?
        render json: { error: 'Subject and message are required' }, status: :bad_request
        return
      end

      # Send email using the custom communication mailer
      SellerCommunicationsMailer.custom_communication(
        seller: queue_item.seller,
        subject: subject,
        message: message,
        user_type: 'seller'
      ).deliver_later

      render json: { success: true, message: 'Email queued for delivery' }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Queue item not found' }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /sales/call_center/send_email_direct
    def send_email_direct
      email = params[:to]
      customer_name = params[:customerName]
      subject = params[:subject]
      message = params[:message]

      if email.blank? || subject.blank? || message.blank?
        render json: { error: 'Email, subject, and message are required' }, status: :bad_request
        return
      end

      # Find seller by email
      seller = Seller.find_by(email: email)
      
      if seller
        # Send email using the custom communication mailer
        SellerCommunicationsMailer.custom_communication(
          seller: seller,
          subject: subject,
          message: message,
          user_type: 'seller'
        ).deliver_later
      else
        # For buyers or non-sellers, we could use a different mailer or skip
        render json: { error: 'Seller not found with this email' }, status: :not_found
        return
      end

      render json: { success: true, message: 'Email queued for delivery' }
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # GET /sales/call_center/customers
    def customers
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 10).to_i
      search = params[:search].to_s.downcase

      # Optimized SQL UNION to query all buyers, sellers, and external callers at once
      sql = <<-SQL
        WITH seller_ads AS (
          SELECT seller_id, COUNT(*) AS ad_count FROM ads WHERE deleted = false GROUP BY seller_id
        ),
        unified_customers AS (
          SELECT id::text, fullname AS name, email, phone_number AS phone, 'Buyer' AS role, created_at, profile_picture, NULL AS enterprise_name, 0 AS ad_count FROM buyers
          UNION ALL
          SELECT s.id::text, s.fullname AS name, s.email, s.phone_number AS phone, 'Seller' AS role, s.created_at, s.profile_picture, s.enterprise_name, COALESCE(a.ad_count, 0) AS ad_count 
          FROM sellers s
          LEFT JOIN seller_ads a ON s.id = a.seller_id
          UNION ALL
          SELECT gen_random_uuid()::text AS id, caller_name AS name, NULL AS email, caller_phone AS phone, 'Lead' AS role, MIN(started_at) AS created_at, NULL AS profile_picture, NULL AS enterprise_name, 0 AS ad_count
          FROM call_records
          WHERE customer_id IS NULL AND (caller_name IS NOT NULL OR caller_phone IS NOT NULL)
          GROUP BY caller_name, caller_phone
        )
        SELECT * FROM unified_customers
      SQL

      conditions = []
      values = []

      if search.present?
        conditions << "(LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR phone LIKE ?)"
        term = "%#{search}%"
        values.push(term, term, term)
      end

      where_clause = conditions.any? ? " WHERE #{conditions.join(' AND ')} " : ""
      
      count_sql = "SELECT COUNT(*) FROM (#{sql} #{where_clause}) AS count_query"
      total_count = ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql_array([count_sql, *values])).to_i

      order_clause = " ORDER BY created_at DESC "
      limit_clause = " LIMIT ? OFFSET ? "
      values.push(per_page, (page - 1) * per_page)

      data_sql = "SELECT * FROM (#{sql}) AS data_query #{where_clause} #{order_clause} #{limit_clause}"
      records = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql_array([data_sql, *values]))

      customers_data = records.map do |r|
        {
          id: r['id'],
          name: r['name'].presence || 'Unknown',
          email: r['email'].presence || 'N/A',
          phone: r['phone'].presence || 'N/A',
          role: r['role'],
          joinedAt: r['created_at'],
          avatar: r['profile_picture'],
          shopName: r['enterprise_name'],
          adCount: r['ad_count'].to_i
        }
      end

      render json: {
        customers: customers_data,
        total_pages: (total_count.to_f / per_page).ceil,
        current_page: page,
        total_count: total_count
      }
    end

    private

    def format_duration(seconds)
      return "00:00" unless seconds && seconds > 0
      minutes = seconds / 60
      remaining_seconds = seconds % 60
      format("%02d:%02d", minutes, remaining_seconds)
    end

    def current_user
      @current_user
    end

    def authenticate_user
      # Assuming standard JWT auth is handled here or in ApplicationController
      # For now, we'll just parse the header if present
      header = request.headers['Authorization']
      if header.present?
        token = header.split(' ').last
        begin
          decoded = JsonWebToken.decode(token)
          user_id = decoded[:user_id] || decoded[:seller_id]
          # Try to find user
          @current_user = SalesUser.find_by(id: user_id) || Admin.find_by(id: user_id)
        rescue StandardError => e
          Rails.logger.error "Auth error: #{e.message}"
        end
      end
      
      # For development, allow request to proceed even if auth fails
      # In production, you'd return 401 Unauthorized here
    end
  end
end
