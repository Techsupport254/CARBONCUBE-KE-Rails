class ContactController < ApplicationController
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # POST /contact/submit
  def submit
    contact_params = params.permit(:name, :email, :phone, :subject, :message)
    
    # Validate required fields
    if contact_params[:name].blank? || contact_params[:email].blank? || 
       contact_params[:subject].blank? || contact_params[:message].blank?
      return render json: { 
        success: false, 
        error: 'All fields are required' 
      }, status: :bad_request
    end
    
    # Validate email format
    unless contact_params[:email].match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return render json: { 
        success: false, 
        error: 'Invalid email format' 
      }, status: :bad_request
    end
    
    begin
      # Send contact form email to admin
      ContactMailer.with(
        name: contact_params[:name],
        email: contact_params[:email],
        phone: contact_params[:phone],
        subject: contact_params[:subject],
        message: contact_params[:message]
      ).contact_form.deliver_now
      
      # Send auto-reply to user
      ContactMailer.with(
        name: contact_params[:name],
        email: contact_params[:email],
        subject: contact_params[:subject]
      ).auto_reply.deliver_now
      
      render json: { 
        success: true, 
        message: 'Thank you for contacting us! We will get back to you within 24 hours.' 
      }, status: :ok
      
    rescue => e
      Rails.logger.error "Contact form submission error: #{e.message}"
      render json: { 
        success: false, 
        error: 'There was an error sending your message. Please try again later.' 
      }, status: :internal_server_error
    end
  end
end
