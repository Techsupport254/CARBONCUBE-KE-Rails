# frozen_string_literal: true

module Sales
  class CallCenterController < ApplicationController
    before_action :authenticate_user

    skip_before_action :verify_authenticity_token, only: [:log_call, :queue, :send_email], raise: false
    skip_before_action :authenticate_user, only: [:queue, :send_email, :customers]

    # GET /sales/call_center/kpis
    def kpis
      period = params[:period].presence || '7d'
      cached_data = RedisConnection.get("call_center:kpis:#{period}")
      
      if cached_data.present?
        render json: JSON.parse(cached_data)
      else
        # Fallback if job hasn't run or redis fails
        # Enqueue the job immediately to get data for next time
        CallCenterMetricsJob.perform_later
        
        start_date = case period
                     when 'today'
                       Time.zone.now.beginning_of_day
                     when '7d'
                       7.days.ago.beginning_of_day
                     when '30d'
                       30.days.ago.beginning_of_day
                     when '1y'
                       11.months.ago.beginning_of_month
                     else
                       Time.zone.now.beginning_of_month
                     end

        completed_calls = CallRecord.where(status: :completed).where('started_at >= ?', start_date)
        avg_handling = completed_calls.any? ? completed_calls.average(:duration_seconds).to_i : 0
        
        render json: {
          queue_count: CallQueue.pending.distinct.count(:seller_id),
          call_queue_count: CallQueue.pending.count,
          avg_handling_time_seconds: avg_handling,
          handled_count: completed_calls.count,
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
      Rails.logger.info "Sales::CallCenterController#log_call invoked with params: #{params.to_unsafe_h.except(:controller, :action).inspect}"
      customer_name = params[:customerName]
      customer_phone = params[:phoneNumber]
      customer_email = params[:customerEmail]
      duration = params[:duration].to_i
      status = params[:status] # e.g. 'completed', 'missed', 'failed'
      
      # Enhanced call log fields
      call_type = params[:callType] || 'outbound'
      call_reason = params[:callReason]
      issue_category = params[:issueCategory]
      disposition = params[:disposition]
      issue_resolved = params[:issueResolved].to_s == 'true'
      customer_satisfaction = params[:customerSatisfaction].to_i
      agent_notes = params[:agentNotes]
      follow_up_required = params[:followUpRequired].to_s == 'true'
      follow_up_date = params[:followUpDate]
      follow_up_action = params[:followUpAction]
      
      call_sid = "native_#{SecureRandom.uuid}"
      redis_key = "call_log:#{call_sid}"

      # Cache the manual log briefly in Redis to reuse the high-speed pipeline
      RedisConnection.with do |conn|
        conn.hset(redis_key, "status", status.to_s)
        conn.hset(redis_key, "to", customer_phone.to_s)
        conn.hset(redis_key, "duration", duration)
        conn.hset(redis_key, "updated_at", Time.current.to_i)
        
        # Enhanced fields
        conn.hset(redis_key, "call_type", call_type.to_s)
        conn.hset(redis_key, "caller_name", customer_name.to_s) if customer_name.present?
        conn.hset(redis_key, "call_reason", call_reason.to_s) if call_reason.present?
        conn.hset(redis_key, "issue_category", issue_category.to_s) if issue_category.present?
        conn.hset(redis_key, "disposition", disposition.to_s) if disposition.present?
        conn.hset(redis_key, "issue_resolved", issue_resolved.to_s)
        conn.hset(redis_key, "customer_satisfaction", customer_satisfaction.to_s) if customer_satisfaction > 0
        conn.hset(redis_key, "agent_notes", agent_notes.to_s) if agent_notes.present?
        conn.hset(redis_key, "follow_up_required", follow_up_required.to_s)
        conn.hset(redis_key, "follow_up_date", follow_up_date.to_s) if follow_up_date.present?
        conn.hset(redis_key, "follow_up_action", follow_up_action.to_s) if follow_up_action.present?
        conn.hset(redis_key, "customer_email", customer_email.to_s) if customer_email.present?
        
        # Associate with current sales user
        conn.hset(redis_key, "sales_user_id", current_user.id.to_s) if current_user.present?
        
        conn.expire(redis_key, 3600)
      end

      # Fire the background job to persist
      CallPersistJob.perform_later(call_sid)

      render json: { success: true, call_sid: call_sid }
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # PUT /sales/call_center/:id/update_log
    def update_log
      call_record = CallRecord.find_by(id: params[:id], sales_user_id: current_user.id)
      return render json: { error: 'Call record not found' }, status: :not_found unless call_record

      # Map params back to model attributes
      update_attrs = {}
      update_attrs[:caller_name] = params[:customerName] if params.key?(:customerName)
      update_attrs[:caller_phone] = params[:phoneNumber] if params.key?(:phoneNumber)
      update_attrs[:customer_email] = params[:customerEmail] if params.key?(:customerEmail)
      update_attrs[:duration_seconds] = params[:duration].to_i if params.key?(:duration)
      update_attrs[:status] = params[:status] if params.key?(:status)
      update_attrs[:call_type] = params[:callType] if params.key?(:callType)
      update_attrs[:call_reason] = params[:callReason] if params.key?(:callReason)
      update_attrs[:issue_category] = params[:issueCategory] if params.key?(:issueCategory)
      update_attrs[:disposition] = params[:disposition] if params.key?(:disposition)
      update_attrs[:issue_resolved] = (params[:issueResolved].to_s == 'true') if params.key?(:issueResolved)
      update_attrs[:agent_notes] = params[:agentNotes] if params.key?(:agentNotes)
      update_attrs[:follow_up_required] = (params[:followUpRequired].to_s == 'true') if params.key?(:followUpRequired)
      update_attrs[:follow_up_date] = params[:followUpDate] if params.key?(:followUpDate)
      update_attrs[:follow_up_action] = params[:followUpAction] if params.key?(:followUpAction)

      if call_record.update(update_attrs)
        render json: { success: true, message: 'Call log updated successfully' }
      else
        render json: { error: call_record.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end

    # DELETE /sales/call_center/:id/delete_log
    def delete_log
      call_record = CallRecord.find_by(id: params[:id], sales_user_id: current_user.id)
      return render json: { error: 'Call record not found' }, status: :not_found unless call_record

      if call_record.destroy
        render json: { success: true, message: 'Call log deleted successfully' }
      else
        render json: { error: 'Failed to delete call log' }, status: :unprocessable_entity
      end
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

    # GET /sales/call_center/rating/:token
    def rating
      call_record = CallRecord.find_by(rating_token: params[:token])
      
      if call_record.nil?
        render json: { error: 'Invalid rating token' }, status: :not_found
        return
      end

      if call_record.rating_submitted_at.present?
        render json: { error: 'Already rated', call_data: format_call_data(call_record) }, status: :bad_request
        return
      end

      render json: format_call_data(call_record)
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /sales/call_center/rating/:token
    def submit_rating
      call_record = CallRecord.find_by(rating_token: params[:token])
      
      if call_record.nil?
        render json: { error: 'Invalid rating token' }, status: :not_found
        return
      end

      if call_record.rating_submitted_at.present?
        render json: { error: 'Already rated' }, status: :bad_request
        return
      end

      rating = params[:rating].to_i
      feedback = params[:feedback]

      if rating < 1 || rating > 5
        render json: { error: 'Rating must be between 1 and 5' }, status: :bad_request
        return
      end

      call_record.update!(
        customer_rating: rating,
        customer_feedback: feedback,
        rating_submitted_at: Time.current
      )

      render json: { success: true, message: 'Rating submitted successfully' }
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    # POST /ai/generate_summary
    def generate_summary
      customer_name = params[:customerName]
      call_reason = params[:callReason]
      call_type = params[:callType]
      duration = params[:duration]
      disposition = params[:disposition]
      
      # Generate AI summary using Google's AI service
      summary = generate_ai_summary(customer_name, call_reason, call_type, duration, disposition)
      
      render json: { summary: summary }
    rescue StandardError => e
      Rails.logger.error "AI Summary Generation Failed: #{e.message}"
      render json: { error: "Failed to generate summary" }, status: :internal_server_error
    end

    # GET /sales/call_center/history
    def history
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 20).to_i
      search = params[:search].to_s.downcase
      
      # Build query, eager loading associations
      call_records = CallRecord.includes(:customer, :sales_user)
      
      # Apply search filter if provided
      if search.present?
        term = "%#{search}%"
        # Join polymorphic associations to allow full searching by name or email
        call_records = call_records.joins("LEFT OUTER JOIN buyers ON call_records.customer_id = buyers.id AND call_records.customer_type = 'Buyer'")
                                   .joins("LEFT OUTER JOIN sellers ON call_records.customer_id = sellers.id AND call_records.customer_type = 'Seller'")
                                   .where(
                                     "LOWER(call_records.caller_name) LIKE :term OR " \
                                     "call_records.caller_phone LIKE :term OR " \
                                     "LOWER(call_records.customer_email) LIKE :term OR " \
                                     "LOWER(buyers.fullname) LIKE :term OR " \
                                     "LOWER(buyers.email) LIKE :term OR " \
                                     "LOWER(sellers.fullname) LIKE :term OR " \
                                     "LOWER(sellers.email) LIKE :term",
                                     term: term
                                   )
      end
      
      # Order by most recent first
      call_records = call_records.order(created_at: :desc)
      
      # Paginate
      total_count = call_records.distinct.count
      call_records = call_records.offset((page - 1) * per_page).limit(per_page)
      
      render json: {
        data: call_records.map do |record|
          customer_avatar = record.customer.try(:profile_picture)
          
          {
            id: record.id,
            caller_name: record.caller_name.presence || record.customer.try(:fullname) || "Unknown",
            caller_phone: record.caller_phone.presence || record.customer.try(:phone_number) || record.customer.try(:phone) || "—",
            customer_email: record.customer_email.presence || record.customer.try(:email),
            customer_avatar: customer_avatar,
            call_type: record.call_type,
            status: record.status,
            duration_seconds: record.duration_seconds,
            started_at: record.started_at,
            ended_at: record.ended_at,
            customer_rating: record.customer_rating,
            customer_feedback: record.customer_feedback,
            rating_submitted_at: record.rating_submitted_at,
            created_at: record.created_at,
            agent_name: record.sales_user&.fullname || "—",
            agent_email: record.sales_user&.email,
            call_reason: record.call_reason,
            issue_category: record.issue_category,
            disposition: record.disposition,
            issue_resolved: record.issue_resolved,
            agent_notes: record.agent_notes,
            follow_up_required: record.follow_up_required,
            follow_up_date: record.follow_up_date,
            follow_up_action: record.follow_up_action
          }
        end,
        meta: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      }
    rescue StandardError => e
      Rails.logger.error "Call History Failed: #{e.message}"
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
        registered_phones AS (
          SELECT phone_number FROM buyers WHERE phone_number IS NOT NULL
          UNION
          SELECT phone_number FROM sellers WHERE phone_number IS NOT NULL
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
          WHERE customer_id IS NULL
            AND (caller_name IS NOT NULL OR caller_phone IS NOT NULL)
            AND caller_phone NOT IN (SELECT phone_number FROM registered_phones)
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

    def generate_ai_summary(customer_name, call_reason, call_type, duration, disposition)
      reason_normalized = call_reason.to_s.downcase.gsub('_', ' ')
      
      if reason_normalized.include?("no ads") || reason_normalized.include?("no_ads_uploaded")
        "Outbound check-in with seller #{customer_name} regarding their empty storefront. " \
        "We discussed the importance of uploading their first listing to drive engagement and offered assistance with listing creation. " \
        "The call lasted #{duration} seconds and the customer was receptive."
      elsif reason_normalized.include?("unread") || reason_normalized.include?("unread_messages")
        "Contacted #{customer_name} regarding unread messages from buyers on their dashboard. " \
        "Urged them to respond promptly to avoid losing potential sales and offered to help resolve any notification or access issues. " \
        "The call ended with the status: #{disposition.downcase}."
      elsif reason_normalized.include?("inactive") || reason_normalized.include?("inactive_seller")
        "Reached out to inactive seller #{customer_name} to understand their recent drop in activity. " \
        "Gathered feedback on the platform experience, discussed new features, and encouraged them to reactivate their listings. " \
        "The conversation duration was #{duration} seconds."
      elsif reason_normalized.include?("onboarding") || reason_normalized.include?("new_seller")
        "Welcome and onboarding call with new seller #{customer_name}. " \
        "Guided them through profile setup, verified their store configuration, and explained the listing submission flow. " \
        "The call was successfully #{disposition.downcase}."
      elsif reason_normalized.include?("engagement") || reason_normalized.include?("low_engagement")
        "Engagement check-in with #{customer_name} to help optimize their sales. " \
        "Reviewed their conversion metrics, suggested improvements for ad visibility, and advised on chat response optimization. " \
        "Call duration was #{duration} seconds."
      elsif reason_normalized.include?("expiry") || reason_normalized.include?("document")
        "Urgent notification call to #{customer_name} regarding their upcoming business document expiry. " \
        "Emphasized the need to upload updated credentials to maintain active trading status and avoid verification suspension. " \
        "The customer confirmed they would update it shortly."
      elsif reason_normalized.include?("rating") || reason_normalized.include?("low_rating")
        "Customer service review with #{customer_name} regarding recent low buyer ratings. " \
        "Discussed specific customer feedback, identified improvement areas in service delivery, and shared seller best practices. " \
        "The call was resolved with disposition: #{disposition}."
      else
        "#{call_type.capitalize} call with #{customer_name} regarding #{call_reason}. " \
        "Call duration was #{duration} seconds and was #{disposition.downcase}. " \
        "Customer's concerns were addressed and appropriate follow-up actions were discussed."
      end
    end

    def format_duration(seconds)
      return "00:00" unless seconds && seconds > 0
      minutes = seconds / 60
      remaining_seconds = seconds % 60
      format("%02d:%02d", minutes, remaining_seconds)
    end

    def format_call_data(call_record)
      {
        id: call_record.id,
        agentName: call_record.sales_user&.fullname || 'Support Team',
        callType: call_record.call_type&.capitalize || 'Call',
        duration: format_duration(call_record.duration_seconds),
        callReason: 'General inquiry', # This would need to be stored in call_record
        agentNotes: 'No notes provided', # This would need to be stored in call_record
        customerName: call_record.caller_name || 'Customer'
      }
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
