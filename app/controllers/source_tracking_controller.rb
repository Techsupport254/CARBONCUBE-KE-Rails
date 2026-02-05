class SourceTrackingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:track]
  # Prevent Rails from wrapping JSON body under :source_tracking so utm_content/utm_term etc. are at params root
  wrap_parameters false

  def track
    # Check if this is an internal user that should be excluded
    if internal_user_excluded?
      Rails.logger.info "🚫 [SourceTrackingController] Request EXCLUDED from tracking (internal user detected)"
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

    visitor_tracking_service = VisitorTrackingService.new(request)
    visitor = visitor_tracking_service.track_visitor

    if analytic
      render json: { 
        success: true, 
        message: 'Visit tracked successfully',
        source: analytic.source,
        referrer: analytic.referrer
      }, status: :created
    else
      # Log the request details for debugging
      Rails.logger.error "Source tracking failed for request:"
      Rails.logger.error "URL: #{request.url}"
      Rails.logger.error "Referrer: #{request.referrer}"
      Rails.logger.error "User Agent: #{request.user_agent}"
      Rails.logger.error "Params: #{request.params.except('controller', 'action')}"
      
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
    # Always exclude internal users from analytics
    base_scope = Analytic.excluding_internal_users
    
    # Always return all data - filtering will be done on frontend (but excluding internal users)
    source_distribution = Analytic.source_distribution
    utm_source_distribution = Analytic.utm_source_distribution
    utm_medium_distribution = Analytic.utm_medium_distribution
    utm_campaign_distribution = Analytic.utm_campaign_distribution
    utm_content_distribution = Analytic.utm_content_distribution
    utm_term_distribution = Analytic.utm_term_distribution
    referrer_distribution = Analytic.referrer_distribution
    
    # Get total visits (all-time, excluding internal users)
    # Calculate as sum of source_distribution to match frontend expectations
    total_visits = source_distribution.values.sum
    
    # Get all visits with timestamps for frontend filtering (excluding internal users)
    visit_timestamps = base_scope.pluck(:created_at)
    
    # Get visits by day for all time (excluding internal users)
    daily_visits = base_scope
                           .group("DATE(created_at)")
                           .order("DATE(created_at)")
                           .count
    
    # Calculate "other" sources count (incomplete UTM - records with source='other')
    other_sources_count = source_distribution['other'] || 0
    
    render json: {
      total_visits: total_visits,
      source_distribution: source_distribution,
      other_sources_count: other_sources_count,
      utm_source_distribution: utm_source_distribution,
      utm_medium_distribution: utm_medium_distribution,
      utm_campaign_distribution: utm_campaign_distribution,
      utm_content_distribution: utm_content_distribution,
      utm_term_distribution: utm_term_distribution,
      referrer_distribution: referrer_distribution,
      daily_visits: daily_visits,
      visit_timestamps: visit_timestamps,
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
    
    # Optionally check for authenticated users (admin, sales, buyer, seller)
    # This allows exclusion based on user email/role without requiring authentication
    email = nil
    user = nil
    role = nil
    user_name = nil
    
    # Try to get authenticated user (optional - don't fail if not authenticated)
    begin
      user = AdminAuthorizeApiRequest.new(request.headers).result
      if user&.is_a?(Admin)
        email = user.email
        role = 'admin'
        user_name = user.fullname if user.respond_to?(:fullname)
      end
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not an admin, continue checking other user types
    rescue
      # Unexpected error, continue
    end
    
    begin
      sales_user = SalesAuthorizeApiRequest.new(request.headers).result
      if sales_user
        email = sales_user.email
        role = 'sales'
        user_name = sales_user.fullname if sales_user.respond_to?(:fullname)
      end
    rescue
      # SalesAuthorizeApiRequest doesn't raise exceptions, just returns nil
      # Not a sales user, continue
    end
    
    begin
      buyer = BuyerAuthorizeApiRequest.new(request.headers).result
      if buyer
        email = buyer.email if email.blank?
        role = 'buyer' if role.blank?
        user_name = buyer.fullname if buyer.respond_to?(:fullname) && user_name.blank?
      end
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not a buyer, continue
    rescue
      # Unexpected error, continue
    end
    
    begin
      seller = SellerAuthorizeApiRequest.new(request.headers).result
      if seller
        email = seller.email if seller && email.blank?
        role = 'seller' if role.blank?
        user_name = seller.fullname if seller.respond_to?(:fullname) && user_name.blank?
      end
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not a seller, continue
    rescue
      # Unexpected error, continue
    end

    # Check against exclusion rules (device hash, IP, user agent, email, user_name, role)
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address,
      email: email,
      user_name: user_name,
      role: role
    )
  end
end
