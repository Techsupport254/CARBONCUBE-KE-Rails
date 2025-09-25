class DataDeletionController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # POST /data_deletion/request
  def create
    deletion_params = params.permit(:full_name, :email, :phone, :account_type, :reason, :confirmation)
    
    # Validate required fields
    if deletion_params[:full_name].blank? || deletion_params[:email].blank? || 
       deletion_params[:account_type].blank? || deletion_params[:confirmation].blank?
      return render json: { 
        success: false, 
        error: 'All required fields must be provided' 
      }, status: :bad_request
    end
    
    # Validate email format
    unless deletion_params[:email].match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return render json: { 
        success: false, 
        error: 'Invalid email format' 
      }, status: :bad_request
    end
    
    # Validate account type
    unless ['buyer', 'seller'].include?(deletion_params[:account_type].downcase)
      return render json: { 
        success: false, 
        error: 'Account type must be either "buyer" or "seller"' 
      }, status: :bad_request
    end
    
    # Validate confirmation
    unless deletion_params[:confirmation].downcase.include?('yes') || 
           deletion_params[:confirmation].downcase.include?('confirm')
      return render json: { 
        success: false, 
        error: 'You must confirm that you understand the consequences of data deletion' 
      }, status: :bad_request
    end
    
    begin
      # Generate a unique token for tracking this request
      token = SecureRandom.hex(16)
      
      # Store the deletion request in the database
      deletion_request = DataDeletionRequest.create!(
        full_name: deletion_params[:full_name],
        email: deletion_params[:email],
        phone: deletion_params[:phone],
        account_type: deletion_params[:account_type].downcase,
        reason: deletion_params[:reason],
        status: 'pending',
        token: token,
        requested_at: Time.current
      )
      
      # Send notification email to admin
      DataDeletionMailer.with(
        deletion_request: deletion_request
      ).admin_notification.deliver_now
      
      # Send confirmation email to user
      DataDeletionMailer.with(
        deletion_request: deletion_request
      ).user_confirmation.deliver_now
      
      render json: { 
        success: true, 
        message: 'Your data deletion request has been submitted successfully. You will receive a confirmation email shortly.',
        token: token
      }, status: :ok
      
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Data deletion request validation error: #{e.message}"
      render json: { 
        success: false, 
        error: 'There was an error processing your request. Please try again.' 
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Data deletion request submission error: #{e.message}"
      render json: { 
        success: false, 
        error: 'There was an error submitting your request. Please try again later.' 
      }, status: :internal_server_error
    end
  end
  
  # GET /data_deletion/status/:token
  def status
    token = params[:token]
    
    unless token.present?
      return render json: { 
        success: false, 
        error: 'Token is required' 
      }, status: :bad_request
    end
    
    begin
      deletion_request = DataDeletionRequest.find_by(token: token)
      
      unless deletion_request
        return render json: { 
          success: false, 
          error: 'Data deletion request not found' 
        }, status: :not_found
      end
      
      render json: { 
        success: true, 
        status: deletion_request.status,
        requested_at: deletion_request.requested_at,
        processed_at: deletion_request.processed_at,
        message: get_status_message(deletion_request.status)
      }, status: :ok
      
    rescue => e
      Rails.logger.error "Data deletion status check error: #{e.message}"
      render json: { 
        success: false, 
        error: 'There was an error checking the status. Please try again later.' 
      }, status: :internal_server_error
    end
  end
  
  private
  
  def get_status_message(status)
    case status
    when 'pending'
      'Your request is being reviewed. We will process it within 30 days.'
    when 'verified'
      'Your identity has been verified. Your data deletion is being processed.'
    when 'completed'
      'Your data has been successfully deleted from our systems.'
    when 'rejected'
      'Your request was rejected. Please contact support for more information.'
    else
      'Your request status is being updated.'
    end
  end
end
