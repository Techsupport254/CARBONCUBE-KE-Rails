class AdSearchesController < ApplicationController
  before_action :authenticate_user, only: [:create] # Authenticate any user (buyer, seller, admin, sales)
  before_action :authenticate_user_for_index, only: [:index] # For getting recent searches

  def create
    # Determine user role for logging
    role = determine_user_role

    # Check if this is an internal user that should be excluded
    if internal_user_excluded?
      render json: { message: 'Search logged successfully (internal user excluded)' }, status: :created
      return
    end

    # Extract metadata for Redis logging
    metadata = {
      device_hash: params[:metadata]&.dig(:device_hash),
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    }

    # Log search to Redis instead of database
    SearchRedisService.log_search(
      ad_search_params[:search_term],
      @current_user&.id,
      role,
      metadata
    )

    render json: { message: 'Search logged successfully' }, status: :created
  rescue => e
    Rails.logger.error "Failed to log search: #{e.message}"
    # Return success even if Redis fails to avoid breaking search functionality
    render json: { message: 'Search logged successfully' }, status: :created
  end

  # Get recent searches for the current user (authenticated or guest)
  def index
    role = determine_user_role
    device_hash = params[:device_hash] || params[:metadata]&.dig(:device_hash)
    limit = [params[:limit].to_i, 50].select(&:positive?).min || 10 # Max 50, default 10

    # Get recent searches for current user or guest
    recent_searches = SearchRedisService.recent_searches_for_current_user(
      user_id: @current_user&.id,
      role: role,
      device_hash: device_hash,
      limit: limit
    )

    render json: {
      searches: recent_searches,
      count: recent_searches.size,
      user_id: @current_user&.id,
      role: role,
      device_hash: device_hash
    }, status: :ok
  rescue => e
    Rails.logger.error "Failed to fetch recent searches: #{e.message}"
    render json: { searches: [], count: 0, error: 'Failed to fetch recent searches' }, status: :internal_server_error
  end

  private

  # Attempt to authenticate any user (buyer, seller, admin, sales), but do not halt the request
  def authenticate_user
    @current_user = nil

    # Try to authenticate as buyer
    begin
      @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
      return if @current_user
    rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
      # Not a buyer, continue
    end

    # Try to authenticate as seller
    begin
      @current_user = SellerAuthorizeApiRequest.new(request.headers).result
      return if @current_user
    rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
      # Not a seller, continue
    end

    # Try to authenticate as admin
    begin
      @current_user = AdminAuthorizeApiRequest.new(request.headers).result
      return if @current_user
    rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
      # Not an admin, continue
    end

    # Try to authenticate as sales user
    begin
      @current_user = SalesAuthorizeApiRequest.new(request.headers).result
      return if @current_user
    rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
      # Not a sales user, continue
    end

    # If no user authenticated, @current_user remains nil (guest user)
  end

  # Authenticate user for index action (non-blocking, allows guests)
  def authenticate_user_for_index
    authenticate_user # Reuse the same method
  end

  def ad_search_params
    # Only permit search_term since metadata is not stored in the database
    params.permit(:search_term)
  end

  # Determine the role of the current user
  def determine_user_role
    role = nil

    # Check if current user is an admin
    begin
      admin = AdminAuthorizeApiRequest.new(request.headers).result
      if admin&.is_a?(Admin)
        role = 'admin'
      end
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not an admin, continue
    rescue
      # Unexpected error, continue
    end

    # Check if current user is a sales user
    begin
      sales_user = SalesAuthorizeApiRequest.new(request.headers).result
      if sales_user
        role = 'sales'
      end
    rescue
      # Not a sales user, continue
    end

    # Get role from current user if available
    if @current_user && role.blank?
      case @current_user
      when Buyer then role = 'buyer'
      when Seller then role = 'seller'
      when Admin then role = 'admin'
      when SalesUser then role = 'sales'
      end
    end

    # Default to guest if no role determined
    role || 'guest'
  end

  # Check if the current request should be excluded based on internal user criteria
  # This matches the logic in ClickEventsController for consistency
  def internal_user_excluded?
    # Get identifiers from request
    device_hash = params[:device_hash] || params[:metadata]&.dig(:device_hash)
    user_agent = params[:user_agent] || request.user_agent
    ip_address = request.remote_ip
    
    # Get email from authenticated user or from metadata
    email = @current_user&.email
    
    role = nil
    user_name = nil
    
    # Check if current user is an admin - exclude all admin users
    begin
      admin = AdminAuthorizeApiRequest.new(request.headers).result
      if admin&.is_a?(Admin)
        role = 'admin'
        email = admin.email if email.blank?
        user_name = admin.fullname if admin.respond_to?(:fullname)
      end
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not an admin, continue
    rescue
      # Unexpected error, continue
    end
    
    # Check if current user is a sales user
    begin
      sales_user = SalesAuthorizeApiRequest.new(request.headers).result
      if sales_user
        role = 'sales'
        sales_email = sales_user.email
        user_name = sales_user.fullname if sales_user.respond_to?(:fullname)
        email = sales_email if email.blank?
      end
    rescue
      # Not a sales user, continue
    end
    
    # Check other user types
    if email.blank? && @current_user
      email = @current_user.email
      user_name = @current_user.fullname if @current_user.respond_to?(:fullname) && user_name.blank?
      if role.blank?
        case @current_user
        when Buyer then role = 'buyer'
        when Seller then role = 'seller'
        when Admin then role = 'admin'
        when SalesUser then role = 'sales'
        end
      end
    end
    
    if email.blank?
      metadata = params[:metadata] || {}
      email = metadata[:user_email] || metadata['user_email']
      user_name = metadata[:user_name] || metadata['user_name'] if user_name.blank?
      role = metadata[:user_role] || metadata['user_role'] || role
    end

    # Check against exclusion rules
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
