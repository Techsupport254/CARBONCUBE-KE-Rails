class Api::EmailController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # POST /api/email/exists
  def exists
    email = params[:email]&.downcase&.strip
    
    if email.blank?
      return render json: { exists: false, error: 'Email is required' }, status: :bad_request
    end
    
    # Validate email format
    unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return render json: { exists: false, error: 'Invalid email format' }, status: :bad_request
    end
    
    # Check if email exists in sellers or buyers
    seller_exists = Seller.exists?(email: email)
    buyer_exists = Buyer.exists?(email: email)
    
    exists = seller_exists || buyer_exists
    
    render json: { 
      exists: exists,
      type: seller_exists ? 'seller' : (buyer_exists ? 'buyer' : nil)
    }, status: :ok
  rescue => e
    Rails.logger.error "Email check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end

  # POST /api/username/exists
  def username_exists
    username = params[:username]&.strip
    
    if username.blank?
      return render json: { exists: false, error: 'Username is required' }, status: :bad_request
    end
    
    # Validate username format (alphanumeric, underscores, hyphens, 3-20 chars)
    unless username.match?(/\A[a-zA-Z0-9_-]{3,20}\z/)
      return render json: { exists: false, error: 'Username must be 3-20 characters and contain only letters, numbers, underscores, and hyphens' }, status: :bad_request
    end
    
    # Check if username exists in sellers or buyers
    seller_exists = Seller.exists?(username: username)
    buyer_exists = Buyer.exists?(username: username)
    
    exists = seller_exists || buyer_exists
    
    render json: { 
      exists: exists,
      type: seller_exists ? 'seller' : (buyer_exists ? 'buyer' : nil)
    }, status: :ok
  rescue => e
    Rails.logger.error "Username check error: #{e.message}"
    render json: { exists: false, error: 'Internal server error' }, status: :internal_server_error
  end
end
