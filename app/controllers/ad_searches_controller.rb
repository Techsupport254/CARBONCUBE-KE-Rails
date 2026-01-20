class AdSearchesController < ApplicationController
  before_action :authenticate_buyer, only: [:create] # Ensure buyer authentication

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

  private

  # Attempt to authenticate the buyer, but do not halt the request
  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
    @current_user = nil
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
  def internal_user_excluded?
    # Get identifiers from request
    device_hash = params[:metadata]&.dig(:device_hash)
    user_agent = request.user_agent
    ip_address = request.remote_ip
    email = @current_user&.email

    role = determine_user_role
    user_name = nil

    # Get user name from current user if available
    if @current_user
      user_name = @current_user.fullname if @current_user.respond_to?(:fullname)
    elsif role == 'admin'
      # Try to get admin name for exclusion check
      begin
        admin = AdminAuthorizeApiRequest.new(request.headers).result
        user_name = admin.fullname if admin.respond_to?(:fullname)
        email = admin.email if email.blank?
      rescue
        # Continue
      end
    elsif role == 'sales'
      # Try to get sales user name for exclusion check
      begin
        sales_user = SalesAuthorizeApiRequest.new(request.headers).result
        user_name = sales_user.fullname if sales_user.respond_to?(:fullname)
        email = sales_user.email if email.blank?
      rescue
        # Continue
      end
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
