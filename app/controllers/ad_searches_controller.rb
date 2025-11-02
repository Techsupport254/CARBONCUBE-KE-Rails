class AdSearchesController < ApplicationController
  before_action :authenticate_buyer, only: [:create] # Ensure buyer authentication

  def create
    # Check if this is an internal user that should be excluded
    if internal_user_excluded?
      render json: { message: 'Search logged successfully (internal user excluded)' }, status: :created
      return
    end

    ad_search = AdSearch.new(ad_search_params)

    # Assign buyer_id only if @current_user is present
    ad_search.buyer_id = @current_user&.id

    if ad_search.save
      render json: { message: 'Search logged successfully' }, status: :created
    else
      render json: { errors: ad_search.errors.full_messages }, status: :unprocessable_entity
    end
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

  # Check if the current request should be excluded based on internal user criteria
  def internal_user_excluded?
    # Get identifiers from request
    device_hash = params[:metadata]&.dig(:device_hash)
    user_agent = request.user_agent
    ip_address = request.remote_ip
    email = @current_user&.email
    
    # Check if current user is an admin - exclude all admin users
    begin
      admin = AdminAuthorizeApiRequest.new(request.headers).result
      if admin&.is_a?(Admin)
        return true
      end
      email = admin&.email if email.blank? && admin
    rescue ExceptionHandler::InvalidToken, ExceptionHandler::MissingToken
      # Not an admin, continue
    rescue
      # Unexpected error, continue
    end
    
    # Check if current user is sales@example.com
    begin
      sales_user = SalesAuthorizeApiRequest.new(request.headers).result
      if sales_user
        sales_email = sales_user.email
        return true if sales_email&.downcase == 'sales@example.com'
        email = sales_email if email.blank?
      end
    rescue
      # Not a sales user, continue
    end

    # Check against exclusion rules
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address,
      email: email
    )
  end
end
