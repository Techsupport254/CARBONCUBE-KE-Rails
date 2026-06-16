class Sales::GoogleAnalyticsController < ApplicationController
  before_action :authenticate_sales_user

  def sources
    start_date = params[:start_date] || '2024-10-07'
    end_date = params[:end_date] || 'today'

    service = GoogleAnalyticsService.new
    sources_data = service.sources_report(start_date: start_date, end_date: end_date)
    source_breakdown = service.sources_by_source_report(start_date: start_date, end_date: end_date)
    totals_data = service.totals_report(start_date: start_date, end_date: end_date)

    render json: {
      ga4: {
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
    }
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
