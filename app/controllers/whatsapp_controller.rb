class WhatsappController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # POST /whatsapp/check or GET /whatsapp/check?phone_number=...
  def check_number
    # Handle both GET and POST requests
    phone_number = params[:phone_number]&.strip || params[:phoneNumber]&.strip
    
    if phone_number.blank?
      return render json: { 
        isRegistered: false, 
        error: 'Phone number is required' 
      }, status: :bad_request
    end
    
    # Validate phone number format (accept various international and local formats)
    cleaned_number = phone_number.gsub(/\D/, '')
    unless cleaned_number.length >= 7 && cleaned_number.length <= 15
      return render json: {
        isRegistered: false,
        error: 'Invalid phone number format. Please enter a valid phone number.'
      }, status: :bad_request
    end
    
    begin
      # Use the WhatsApp notification service to check if number is registered
      result = WhatsAppNotificationService.check_number(cleaned_number)
      
      if result[:success]
        render json: {
          isRegistered: result[:isRegistered],
          phoneNumber: result[:phoneNumber],
          formattedNumber: result[:formattedNumber],
          method: result[:method] || 'unknown'
        }, status: :ok
      else
        # If format is invalid, return false
        render json: {
          isRegistered: false,
          phoneNumber: cleaned_number,
          error: result[:error]
        }, status: :ok
      end
    rescue => e
      Rails.logger.error "WhatsApp check error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        isRegistered: false, 
        error: 'Internal server error',
        phoneNumber: cleaned_number
      }, status: :internal_server_error
    end
  end
end

