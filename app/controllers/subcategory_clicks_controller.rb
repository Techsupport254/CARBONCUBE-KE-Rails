class SubcategoryClicksController < ApplicationController
  before_action :authenticate_buyer, only: [:create]

  def create
    # Check if this is an internal user that should be excluded
    if internal_user_excluded?
      render json: { message: 'Subcategory click logged successfully (internal user excluded)' }, status: :created
      return
    end

    # For now, just log the subcategory click without saving to database
    # You can create a SubcategoryClick model later if needed
    render json: { message: 'Subcategory click logged successfully' }, status: :created
  end

  private

  # Attempt to authenticate the buyer, but do not halt the request
  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
  rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken
    @current_user = nil
  end

  def subcategory_click_params
    params.permit(:subcategory, :category, metadata: {})
  end

  # Check if the current request should be excluded based on internal user criteria
  def internal_user_excluded?
    # Get identifiers from request
    device_hash = params[:metadata]&.dig(:device_hash)
    user_agent = request.user_agent
    ip_address = request.remote_ip
    email = @current_user&.email

    # Check against exclusion rules
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      ip_address: ip_address,
      email: email
    )
  end
end
