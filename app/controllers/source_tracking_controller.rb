class SourceTrackingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:track]
  
  def track
    # Check if this is an internal user that should be excluded
    if internal_user_excluded?
      render json: { 
        success: true, 
        message: 'Visit tracked successfully (internal user excluded)',
        source: 'internal_user_excluded',
        referrer: 'internal_user_excluded'
      }, status: :created
      return
    end

    # Track the visit using the service
    tracking_service = SourceTrackingService.new(request)
    analytic = tracking_service.track_visit
    
    if analytic
      render json: { 
        success: true, 
        message: 'Visit tracked successfully',
        source: analytic.source,
        referrer: analytic.referrer
      }, status: :created
    else
      # Log the request details for debugging
      Rails.logger.error "❌ Source tracking failed for request:"
      Rails.logger.error "❌ URL: #{request.url}"
      Rails.logger.error "❌ Referrer: #{request.referrer}"
      Rails.logger.error "❌ User Agent: #{request.user_agent}"
      Rails.logger.error "❌ Params: #{request.params.except('controller', 'action')}"
      
      render json: { 
        success: false, 
        message: 'Failed to track visit - check server logs for details',
        debug_info: {
          url: request.url,
          referrer: request.referrer,
          source: request.params[:source],
          utm_source: request.params[:utm_source]
        }
      }, status: :unprocessable_entity
    end
  end

  def analytics
    # Get analytics data for the sales dashboard
    days = params[:days]&.to_i || 30
    
    source_distribution = Analytic.source_distribution(days)
    utm_source_distribution = Analytic.utm_source_distribution(days)
    utm_medium_distribution = Analytic.utm_medium_distribution(days)
    utm_campaign_distribution = Analytic.utm_campaign_distribution(days)
    referrer_distribution = Analytic.referrer_distribution(days)
    
    # Get total visits
    total_visits = Analytic.recent(days).count
    
    # Get visits by day for the last 30 days
    daily_visits = Analytic.recent(days)
                           .group("DATE(created_at)")
                           .order("DATE(created_at)")
                           .count
    
    render json: {
      total_visits: total_visits,
      source_distribution: source_distribution,
      utm_source_distribution: utm_source_distribution,
      utm_medium_distribution: utm_medium_distribution,
      utm_campaign_distribution: utm_campaign_distribution,
      referrer_distribution: referrer_distribution,
      daily_visits: daily_visits,
      top_sources: source_distribution.sort_by { |_, count| -count }.first(10),
      top_referrers: referrer_distribution.sort_by { |_, count| -count }.first(10)
    }
  end

  private

  # Check if the current request should be excluded based on internal user criteria
  def internal_user_excluded?
    # Get identifiers from request
    device_hash = params[:device_hash]
    user_agent = request.user_agent
    ip_address = request.remote_ip
    email = nil # No user authentication for source tracking

    # Check against exclusion rules
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address,
      email: email
    )
  end
end
