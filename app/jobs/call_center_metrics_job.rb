class CallCenterMetricsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # 1. Compute KPIs
    queue_count = CallRecord.where(status: :pending).count

    completed_today = CallRecord.where(status: :completed)
                                .where('started_at >= ?', Time.zone.now.beginning_of_day)
    
    avg_handling_time_seconds = if completed_today.any?
                                  completed_today.average(:duration_seconds).to_i
                                else
                                  0
                                end

    handled_count = completed_today.count

    handled_yesterday = CallRecord.where(status: :completed)
                                  .where(started_at: 1.day.ago.beginning_of_day..1.day.ago.end_of_day).count
    handled_trend = handled_count - handled_yesterday

    recent_csat = CallRecord.where.not(csat_score: nil)
                            .where('started_at >= ?', 30.days.ago)
    
    csat_avg = if recent_csat.any?
                 (recent_csat.average(:csat_score).to_f / 5.0 * 100).round
               else
                 100
               end

    kpis = {
      queue_count: queue_count,
      call_queue_count: CallQueue.pending.count,
      avg_handling_time_seconds: avg_handling_time_seconds,
      handled_count: handled_count,
      handled_trend: handled_trend,
      csat_score: csat_avg
    }

    RedisConnection.setex('call_center:kpis', 10.minutes.to_i, kpis.to_json)

    # 1.5. Populate call queue based on seller metrics
    CallQueueService.populate_queue

    # 2. Compute Chart Data for all periods
    periods = ['today', '7d', '30d', '1y', 'all']
    
    periods.each do |period|
      chart_data = compute_chart_data(period)
      RedisConnection.setex("call_center:chart_data:#{period}", 10.minutes.to_i, chart_data.to_json)
    end

    # 3. Schedule next run recursively
    # This acts as a poor man's cron if sidekiq-cron isn't installed
    CallCenterMetricsJob.set(wait: 5.minutes).perform_later
  end

  private

  def compute_chart_data(period)
    case period
    when 'today'
      start_date = Time.zone.now.beginning_of_day
      records = CallRecord.where('started_at >= ?', start_date)
      
      handled_by_hour = records.where(status: :completed).group("EXTRACT(HOUR FROM started_at)").count
      missed_by_hour = records.where(status: [:missed, :abandoned]).group("EXTRACT(HOUR FROM started_at)").count
      
      current_hour = Time.zone.now.hour
      (0..current_hour).map do |hour|
        {
          date: format('%02d:00', hour),
          handled: handled_by_hour[hour.to_f] || 0,
          missed: missed_by_hour[hour.to_f] || 0
        }
      end
    when '1y'
      start_date = 1.year.ago.beginning_of_month
      records = CallRecord.where('started_at >= ?', start_date)
      
      handled_by_month = records.where(status: :completed).group("DATE_TRUNC('month', started_at)").count
      missed_by_month = records.where(status: [:missed, :abandoned]).group("DATE_TRUNC('month', started_at)").count
      
      (0..11).map do |i|
        month_date = start_date + i.months
        h_count = handled_by_month.find { |k, v| k.to_date.year == month_date.year && k.to_date.month == month_date.month }&.last || 0
        m_count = missed_by_month.find { |k, v| k.to_date.year == month_date.year && k.to_date.month == month_date.month }&.last || 0
        
        {
          date: month_date.strftime('%Y-%m'),
          handled: h_count,
          missed: m_count
        }
      end
    when 'all'
      first_record = CallRecord.order(started_at: :asc).first
      start_date = first_record ? first_record.started_at.beginning_of_month : Time.zone.now.beginning_of_month
      records = CallRecord.all
      
      handled_by_month = records.where(status: :completed).group("DATE_TRUNC('month', started_at)").count
      missed_by_month = records.where(status: [:missed, :abandoned]).group("DATE_TRUNC('month', started_at)").count
      
      months_diff = (Time.zone.now.year * 12 + Time.zone.now.month) - (start_date.year * 12 + start_date.month)
      months_diff = [months_diff, 0].max
      
      (0..months_diff).map do |i|
        month_date = start_date + i.months
        h_count = handled_by_month.find { |k, v| k.to_date.year == month_date.year && k.to_date.month == month_date.month }&.last || 0
        m_count = missed_by_month.find { |k, v| k.to_date.year == month_date.year && k.to_date.month == month_date.month }&.last || 0
        
        {
          date: month_date.strftime('%Y-%m'),
          handled: h_count,
          missed: m_count
        }
      end
    else # '7d' or '30d'
      days = period == '30d' ? 30 : 7
      start_date = days.days.ago.beginning_of_day
      records = CallRecord.where('started_at >= ?', start_date)

      handled_by_date = records.where(status: :completed).group('DATE(started_at)').count
      missed_by_date = records.where(status: [:missed, :abandoned]).group('DATE(started_at)').count

      (0...days).map do |i|
        date = (start_date + i.days).to_date
        {
          date: date.to_s,
          handled: handled_by_date[date] || 0,
          missed: missed_by_date[date] || 0
        }
      end
    end
  end
end
