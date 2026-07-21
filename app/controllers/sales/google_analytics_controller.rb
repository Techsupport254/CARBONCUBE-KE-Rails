class Sales::GoogleAnalyticsController < ApplicationController
  before_action :authenticate_sales_user

  def sources
    start_date = params[:start_date] || '2024-10-07'
    end_date = params[:end_date] || 'today'

    cache_key = "ga4_sources_v1_#{start_date}_#{end_date}"
    result = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      service = GoogleAnalyticsService.new

      # Run all 3 GA4 API calls concurrently instead of serially
      sources_data_holder = nil
      source_breakdown_holder = nil
      totals_data_holder = nil

      t1 = Thread.new { sources_data_holder = service.sources_report(start_date: start_date, end_date: end_date) }
      t2 = Thread.new { source_breakdown_holder = service.sources_by_source_report(start_date: start_date, end_date: end_date) }
      t3 = Thread.new { totals_data_holder = service.totals_report(start_date: start_date, end_date: end_date) }

      [t1, t2, t3].each(&:join)

      sources_data = sources_data_holder
      source_breakdown = source_breakdown_holder
      totals_data = totals_data_holder

      {
        total_sessions: sources_data[:total_sessions],
        total_users: sources_data[:total_users],
        total_new_users: sources_data[:total_new_users],
        page_views: totals_data[:page_views],
        channel_distribution: sources_data[:channel_distribution],
        top_channel: sources_data[:top_channel],
        source_breakdown: source_breakdown[:sources],
        top_source: source_breakdown[:top_source],
        error: sources_data[:error]
      }
    end

    render json: { ga4: result }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
