class EmailController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # POST /email/exists
  def exists
    email = params[:email]&.downcase&.strip
    
    if email.blank?
      return render json: { exists: false, error: 'Email is required' }, status: :bad_request
    end
    
    # Validate email format
    unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return render json: { exists: false, error: 'Invalid email format' }, status: :bad_request
    end
    
    # Check if email exists across all user models
    seller_exists = Seller.exists?(email: email)
    buyer_exists = Buyer.exists?(email: email)
    admin_exists = Admin.exists?(email: email)
    sales_user_exists = SalesUser.exists?(email: email)
    
    exists = seller_exists || buyer_exists || admin_exists || sales_user_exists
    
    # Determine which type of user has this email
    user_type = if seller_exists
                  'seller'
                elsif buyer_exists
                  'buyer'
                elsif admin_exists
                  'admin'
                elsif sales_user_exists
                  'sales'
                else
                  nil
                end
    
    render json: { 
      exists: exists,
      type: user_type
    }, status: :ok
  rescue => e
    Rails.logger.error "Email check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end

  # POST /username/exists
  def username_exists
    username = params[:username]&.strip
    
    if username.blank?
      return render json: { exists: false, error: 'Username is required' }, status: :bad_request
    end
    
    # Validate username format (alphanumeric, underscores only, no spaces, 3-20 chars)
    unless username.match?(/\A[a-zA-Z0-9_]{3,20}\z/)
      return render json: { exists: false, error: 'Username must be 3-20 characters and contain only letters, numbers, and underscores (no spaces or hyphens)' }, status: :bad_request
    end
    
    # Check if username exists across all user models
    seller_exists = Seller.exists?(username: username)
    buyer_exists = Buyer.exists?(username: username)
    admin_exists = Admin.exists?(username: username)
    
    exists = seller_exists || buyer_exists || admin_exists
    
    # Determine which type of user has this username
    user_type = if seller_exists
                  'seller'
                elsif buyer_exists
                  'buyer'
                elsif admin_exists
                  'admin'
                else
                  nil
                end
    
    render json: { 
      exists: exists,
      type: user_type
    }, status: :ok
  rescue => e
    Rails.logger.error "Username check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end

  # POST /phone/exists
  def phone_exists
    phone_number = params[:phone_number]&.strip
    
    if phone_number.blank?
      return render json: { exists: false, error: 'Phone number is required' }, status: :bad_request
    end
    
    # Validate phone number format (10 digits)
    unless phone_number.match?(/\A\d{10}\z/)
      return render json: { exists: false, error: 'Phone number must be exactly 10 digits' }, status: :bad_request
    end
    
    # Check if phone number exists across all user models
    seller_exists = Seller.exists?(phone_number: phone_number)
    buyer_exists = Buyer.exists?(phone_number: phone_number)
    
    exists = seller_exists || buyer_exists
    
    # Determine which type of user has this phone number
    user_type = if seller_exists
                  'seller'
                elsif buyer_exists
                  'buyer'
                else
                  nil
                end
    
    render json: { 
      exists: exists,
      type: user_type
    }, status: :ok
  rescue => e
    Rails.logger.error "Phone check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end

  # POST /business_name/exists
  def business_name_exists
    business_name = params[:business_name]&.strip
    
    if business_name.blank?
      return render json: { exists: false, error: 'Business name is required' }, status: :bad_request
    end
    
    # Check if business name exists in sellers (enterprise_name)
    seller_exists = Seller.exists?(enterprise_name: business_name)
    
    render json: { 
      exists: seller_exists,
      type: seller_exists ? 'seller' : nil
    }, status: :ok
  rescue => e
    Rails.logger.error "Business name check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end

  # POST /business_number/exists
  def business_number_exists
    business_number = params[:business_number]&.strip
    
    if business_number.blank?
      return render json: { exists: false, error: 'Business registration number is required' }, status: :bad_request
    end
    
    # Check if business registration number exists in sellers
    seller_exists = Seller.exists?(business_registration_number: business_number)
    
    render json: { 
      exists: seller_exists,
      type: seller_exists ? 'seller' : nil
    }, status: :ok
  rescue => e
    Rails.logger.error "Business number check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end
end
