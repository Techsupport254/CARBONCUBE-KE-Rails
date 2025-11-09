class Sales::ClickEventsController < ApplicationController
  before_action :authenticate_sales_user

  def analytics
    begin
      # Use the unified service as single source of truth
      filters = {
        event_type: params[:event_type],
        user_status: params[:user_status],
        start_date: params[:start_date],
        end_date: params[:end_date],
        seller_id: params[:seller_id] # Optional: for seller-specific analytics
      }.compact
      
      service = ClickEventsAnalyticsService.new(filters: filters)
      
      # Get pagination params
      page = params[:page].to_i
      page = 1 if page < 1
      per_page = params[:per_page].to_i
      per_page = 50 if per_page < 1 || per_page > 100
      
      # Get analytics data from service
      analytics_data = service.analytics
      recent_events_data = service.recent_click_events(page: page, per_page: per_page)
      
      # Format response to match existing frontend expectations
      response_data = {
        # Totals
        total_click_events: analytics_data[:totals][:total_click_events],
        total_reveal_events: analytics_data[:totals][:total_reveal_events],
        total_ad_clicks: analytics_data[:totals][:total_ad_clicks],
        guest_reveals: analytics_data[:totals][:guest_reveals],
        authenticated_reveals: analytics_data[:totals][:authenticated_reveals],
        conversion_count: analytics_data[:totals][:conversion_count],
        conversion_rate: analytics_data[:totals][:conversion_rate],
        post_login_reveal_count: analytics_data[:totals][:post_login_reveal_count],
        guest_login_attempt_count: analytics_data[:totals][:guest_login_attempt_count],

        # Timestamps for frontend filtering
        click_events_timestamps: analytics_data[:timestamps][:click_events_timestamps],
        reveal_events_timestamps: analytics_data[:timestamps][:reveal_events_timestamps],
        ad_clicks_timestamps: analytics_data[:timestamps][:ad_clicks_timestamps],
        guest_reveal_timestamps: analytics_data[:timestamps][:guest_reveal_timestamps],
        authenticated_reveal_timestamps: analytics_data[:timestamps][:authenticated_reveal_timestamps],
        conversion_timestamps: analytics_data[:timestamps][:conversion_timestamps],
        post_login_reveal_timestamps: analytics_data[:timestamps][:post_login_reveal_timestamps],
        guest_login_attempt_timestamps: analytics_data[:timestamps][:guest_login_attempt_timestamps],

        # Top performing ads
        top_ads_by_reveals: analytics_data[:top_ads],
        
        # Recent click events with user details (paginated)
        recent_click_events: recent_events_data[:events],
        recent_click_events_pagination: recent_events_data[:pagination]
      }

      render json: response_data
    rescue => e
      Rails.logger.error "Click events analytics error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
