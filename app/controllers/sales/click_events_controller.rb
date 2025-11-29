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
      
      # Get device_hash from params or headers if available
      # This is used to exclude guest clicks from sellers clicking their own ads
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      
      service = ClickEventsAnalyticsService.new(
        filters: filters,
        device_hash: device_hash
      )
      
      # Get pagination params
      page = params[:page].to_i
      page = 1 if page < 1
      per_page = params[:per_page].to_i
      per_page = 50 if per_page < 1 || per_page > 500
      
      # Check if timestamps are needed (they can be expensive for large datasets)
      include_timestamps = params[:include_timestamps] != 'false'
      
      # Get analytics data from service with optimized options
      analytics_options = {
        include_timestamps: include_timestamps,
        include_breakdowns: true,
        include_top_ads: false  # Top ads are now in dedicated /best_ads endpoint
      }
      analytics_data = service.analytics(options: analytics_options)
      
      # Get recent events without user agent parsing for better performance
      # User agent parsing is expensive and can be done client-side if needed
      recent_events_data = service.recent_click_events(
        page: page, 
        per_page: per_page,
        parse_user_agent: false
      )
      
      # Format response to match existing frontend expectations
      response_data = {
        # Totals
        total_click_events: analytics_data[:totals][:total_click_events],
        total_reveal_events: analytics_data[:totals][:total_reveal_events],
        total_ad_clicks: analytics_data[:totals][:total_ad_clicks],
        total_callback_requests: analytics_data[:totals][:total_callback_requests] || 0,
        guest_reveals: analytics_data[:totals][:guest_reveals],
        authenticated_reveals: analytics_data[:totals][:authenticated_reveals],
        conversion_count: analytics_data[:totals][:conversion_count],
        conversion_rate: analytics_data[:totals][:conversion_rate],
        post_login_reveal_count: analytics_data[:totals][:post_login_reveal_count],
        guest_login_attempt_count: analytics_data[:totals][:guest_login_attempt_count],

        # Timestamps for frontend filtering (safe access in case timestamps failed to load)
        click_events_timestamps: analytics_data[:timestamps]&.dig(:click_events_timestamps) || [],
        reveal_events_timestamps: analytics_data[:timestamps]&.dig(:reveal_events_timestamps) || [],
        ad_clicks_timestamps: analytics_data[:timestamps]&.dig(:ad_clicks_timestamps) || [],
        callback_requests_timestamps: analytics_data[:timestamps]&.dig(:callback_requests_timestamps) || [],
        guest_reveal_timestamps: analytics_data[:timestamps]&.dig(:guest_reveal_timestamps) || [],
        authenticated_reveal_timestamps: analytics_data[:timestamps]&.dig(:authenticated_reveal_timestamps) || [],
        conversion_timestamps: analytics_data[:timestamps]&.dig(:conversion_timestamps) || [],
        post_login_reveal_timestamps: analytics_data[:timestamps]&.dig(:post_login_reveal_timestamps) || [],
        guest_login_attempt_timestamps: analytics_data[:timestamps]&.dig(:guest_login_attempt_timestamps) || [],

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

  # GET /sales/click_events/best_ads
  # Get top 100 best performing ads (optimized endpoint)
  def best_ads
    begin
      filters = {
        start_date: params[:start_date],
        end_date: params[:end_date]
      }.compact
      
      # Get device_hash from params or headers if available
      device_hash = params[:device_hash] || request.headers['X-Device-Hash']
      
      limit = params[:limit].to_i
      limit = 100 if limit < 1 || limit > 100
      
      service = ClickEventsAnalyticsService.new(
        filters: filters,
        device_hash: device_hash
      )
      
      # Get top ads only (no other data needed)
      top_ads = service.top_ads_by_reveals(limit: limit)
      
      render json: {
        ads: top_ads,
        total: top_ads.count,
        limit: limit
      }
    rescue => e
      Rails.logger.error "Best ads error: #{e.message}"
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
