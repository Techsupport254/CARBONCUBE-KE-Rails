class MonitoringService
  class << self
    def track_error(exception, context = {})
      # Store in local database
      MonitoringError.create!(
        message: exception.message,
        stack_trace: exception.backtrace&.join("\n"),
        level: context[:level] || 'error',
        context: context.merge({
          controller: context[:controller],
          action: context[:action],
          user_id: context[:user_id],
          ip_address: context[:ip_address],
          user_agent: context[:user_agent]
        }).compact
      )

      # Send to Sentry if configured
      if Sentry.initialized?
        Sentry.capture_exception(exception, extra: context)
      end

      # Send to Logtail if configured
      Rails.logger.error("MONITORING_ERROR: #{exception.message} - #{context.to_json}")
    end

    def track_metric(name, value, tags = {})
      # Store in local database
      MonitoringMetric.create!(
        name: name,
        value: value,
        timestamp: Time.current,
        tags: tags
      )

      # Only log to stdout in production — in development, metrics are
      # stored in MonitoringMetrics and the log line adds noise.
      Rails.logger.info("MONITORING_METRIC: #{name}=#{value} #{tags.to_json}") unless Rails.env.development?
    end

    def track_performance(controller, action, duration)
      track_metric('request_duration_ms', duration * 1000, {
        controller: controller,
        action: action
      })
    end

    def track_database_query(query, duration)
      track_metric('database_query_ms', duration * 1000, {
        query_type: query_type(query)
      })
    end

    def resolve_error(error_id)
      error = MonitoringError.find(error_id)
      error.update!(resolved_at: Time.current)
      error
    end

    def get_error_summary(timeframe = 24.hours)
      MonitoringError
        .where('created_at > ?', timeframe.ago)
        .where(resolved_at: nil)
        .group(:message)
        .count
        .sort_by { |_, count| -count }
        .first(10)
    end

    def get_metric_summary(timeframe = 24.hours)
      MonitoringMetric
        .where('created_at > ?', timeframe.ago)
        .group(:name)
        .average(:value)
    end

    private

    def query_type(query)
      case query.downcase
      when /select/ then 'SELECT'
      when /insert/ then 'INSERT'
      when /update/ then 'UPDATE'
      when /delete/ then 'DELETE'
      else 'OTHER'
      end
    end
  end
end
