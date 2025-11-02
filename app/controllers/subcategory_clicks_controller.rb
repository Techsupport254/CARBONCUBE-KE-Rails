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
    
    role = nil
    user_name = nil
    
    # Check if current user is an admin
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

    # Get user name and role from current user if available
    if @current_user
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
