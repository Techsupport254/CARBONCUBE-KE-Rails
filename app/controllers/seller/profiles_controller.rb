require 'fileutils'

class Seller::ProfilesController < ApplicationController
  before_action :authenticate_seller
  skip_before_action :authenticate_seller, only: [:pending_registration, :complete_onboarding]
  before_action :set_seller, only: [:show, :update]

  # GET /seller/profile
  def show
    # OPTIMIZATION: Eager load associations to avoid N+1 queries
    @seller = Seller.includes(
      :categories,
      :seller_documents,
      { seller_tier: :tier },
      :carbon_code,
      :county,
      :sub_county,
      :age_group,
      :document_type
    ).find(@seller.id)

    seller_data = SellerSerializer.new(@seller).as_json
    # Check if email is verified
    # Google OAuth users are treated as automatically verified
    if @seller.respond_to?(:provider) && @seller.provider.to_s.downcase == 'google'
      email_verified = true
    else
      email_verified = EmailOtp.exists?(email: @seller.email, verified: true)
    end
    seller_data[:email_verified] = email_verified
    # Check if user has a password set
    # password_digest will be nil or empty string for OAuth users who haven't set a password
    # It will be present (a bcrypt hash) for users who have set a password
    seller_data[:has_password] = @seller.password_digest.present? && !@seller.password_digest.to_s.strip.empty?

    render json: seller_data
  end

  # PATCH/PUT /seller/profile
  def update
    begin
      uploaded_profile_picture_url = nil
      uploaded_document_url = nil
      
      # Handle profile picture upload if present
      if params[:profile_picture].present?
        pic = params[:profile_picture]
        
        # Check if it's actually a file object
        unless pic.respond_to?(:original_filename)
          return render json: { error: "Invalid file format" }, status: :unprocessable_entity
        end

        uploaded_profile_picture_url = handle_upload(
          file: pic,
          type: :profile_picture,
          max_size: 2.megabytes,
          accepted_types: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
          processing_method: :process_and_upload_profile_picture
        )

        if uploaded_profile_picture_url.nil?
          return render json: { error: "Failed to upload profile picture" }, status: :unprocessable_entity
        end
      end

      # Handle document upload if present
      if params[:document].present?
        doc = params[:document]
        
        # Check if it's actually a file object
        unless doc.respond_to?(:original_filename)
          return render json: { error: "Invalid document format" }, status: :unprocessable_entity
        end

        uploaded_document_url = handle_upload(
          file: doc,
          type: :document,
          max_size: 10.megabytes,
          accepted_types: ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'],
          processing_method: :process_and_upload_document
        )

        if uploaded_document_url.nil?
          return render json: { error: "Failed to upload document" }, status: :unprocessable_entity
        end
      end

      # Only update fields that are provided and valid
      update_params = seller_params.reject { |k, v| v.blank? }
      
      # Remove any unexpected fields that might cause issues
      unexpected_fields = ['birthdate', 'created_at', 'updated_at', 'id']
      unexpected_fields.each { |field| update_params.delete(field) }
      
      # Additional filtering for empty strings and null values
      update_params = update_params.reject { |k, v| v.nil? || v.to_s.strip.empty? }

      # Handle explicit phone number removal
      if params[:clear_phone_number] == true || params[:clear_phone_number] == 'true' || params[:phone_number] == 'REMOVE' || params[:phone_number] == 'DELETE'
        update_params[:phone_number] = nil
      end

      # Add the uploaded URLs if available
      update_params[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url
      update_params[:document_url] = uploaded_document_url if uploaded_document_url
      
      # Resolve carbon_code string to carbon_code_id (for OAuth completion modal)
      carbon_code_param = update_params.delete(:carbon_code)
      carbon_code = nil
      if carbon_code_param.present?
        carbon_code = CarbonCode.find_by("UPPER(TRIM(code)) = ?", carbon_code_param.to_s.strip.upcase)
        if carbon_code.nil?
          return render json: { errors: { carbon_code: ["Carbon code is invalid."] } }, status: :unprocessable_entity
        end
        unless carbon_code.valid_for_use?
          msg = carbon_code.expired? ? "This Carbon code has expired." : "This Carbon code has reached its usage limit."
          return render json: { errors: { carbon_code: [msg] } }, status: :unprocessable_entity
        end
        update_params[:carbon_code_id] = carbon_code.id
      end
      
      if @seller.update(update_params)
        carbon_code&.increment!(:times_used)
        seller_data = SellerSerializer.new(@seller).as_json
        # Check if email is verified
        # Google OAuth users are treated as automatically verified
        if @seller.respond_to?(:provider) && @seller.provider.to_s.downcase == 'google'
          email_verified = true
        else
          email_verified = EmailOtp.exists?(email: @seller.email, verified: true)
        end
        seller_data[:email_verified] = email_verified
        # Check if user has a password set
        # password_digest will be nil or empty string for OAuth users who haven't set a password
        # It will be present (a bcrypt hash) for users who have set a password
        seller_data[:has_password] = @seller.password_digest.present? && !@seller.password_digest.to_s.strip.empty?
        render json: seller_data
      else
        render json: { errors: @seller.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      render json: { error: "Failed to update profile: #{e.message}" }, status: :internal_server_error
    end
  end

  # POST /seller/change-password
  def change_password
    # If user has a password, require current password
    if current_seller.password_digest.present?
      # Check if currentPassword was provided
      unless params[:currentPassword].present?
        render json: { error: 'Current password is required' }, status: :unauthorized
        return
      end
      
      # Authenticate the current password
      unless current_seller.authenticate(params[:currentPassword])
        render json: { error: 'Current password is incorrect' }, status: :unauthorized
        return
      end
    end
    
    # Check if new password matches confirmation
    unless params[:newPassword].present? && params[:confirmPassword].present?
      render json: { error: 'New password and confirmation are required' }, status: :unprocessable_entity
      return
    end
    
    if params[:newPassword] == params[:confirmPassword]
      # Update the password
      if current_seller.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: { 
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_seller.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  # POST /seller/profile/request-verification
  def request_verification
    email = current_seller.email
    fullname = current_seller.fullname

    # Google OAuth sellers are automatically verified and do not need an OTP
    if current_seller.respond_to?(:provider) && current_seller.provider.to_s.downcase == 'google'
      render json: { message: "Email is already verified via Google." }, status: :ok
      return
    end

    otp_code = rand.to_s[2..7] # 6-digit code
    expires_at = 10.minutes.from_now

    # Remove old OTPs for this email
    EmailOtp.where(email: email).delete_all

    # Create new OTP
    EmailOtp.create!(
      email: email,
      otp_code: otp_code,
      expires_at: expires_at,
      verified: false
    )

    # Send email
    begin
      OtpMailer.with(email: email, code: otp_code, fullname: fullname).send_otp.deliver_now
    rescue => e
      # Don't fail the request if email fails
    end

    response = { message: "Verification code sent to your email" }
    render json: response, status: :ok
  end

  # POST /seller/profile/verify-email
  def verify_email
    email = current_seller.email

    # Google OAuth sellers are automatically verified and do not need an OTP
    if current_seller.respond_to?(:provider) && current_seller.provider.to_s.downcase == 'google'
      render json: { verified: true, message: "Email is already verified via Google" }, status: :ok
      return
    end

    otp_code = params[:otp_code]

    record = EmailOtp.find_by(email: email, otp_code: otp_code)

    if record.nil?
      render json: { verified: false, error: "Invalid verification code" }, status: :unprocessable_entity
    elsif record.verified == true
      render json: { verified: false, error: "This code has already been used" }, status: :unprocessable_entity
    elsif record.expires_at.present? && record.expires_at <= Time.now
      render json: { verified: false, error: "Verification code has expired" }, status: :unprocessable_entity
    else
      record.update!(verified: true)
      render json: { verified: true, message: "Email verified successfully" }, status: :ok
    end
  end

  private

  def set_seller
    @seller = current_seller
  end

  def seller_params
    params.permit(:fullname, :phone_number, :secondary_phone_number, :email, :enterprise_name, :location, :password, :password_confirmation, :business_registration_number, :gender, :city, :zipcode, :username, :description, :county_id, :sub_county_id, :age_group_id, :profile_picture, :document_url, :document_type_id, :document_expiry_date, :phone_provided_by_oauth, :carbon_code, :facebook_url, :instagram_url, :whatsapp_url, :tiktok_url, :twitter_url, :linkedin_url, :website)
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller && @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_seller
    @current_seller
  end

  public

  def pending_registration
    pending_token = params[:pending_token].to_s
    pending_data = Rails.cache.read("pending_google_registration_#{pending_token}") if pending_token.present?

    unless pending_data.is_a?(Hash) && pending_data[:role].to_s.casecmp?("seller")
      return render json: { error: "Pending registration not found or expired" }, status: :not_found
    end

    render json: {
      name: pending_data[:name],
      phone_number: pending_data[:phone_number],
      email: pending_data[:email]
    }, status: :ok
  end

  # POST /seller/onboarding/complete
  def complete_onboarding
    # This endpoint is for direct seller signup (seller already exists)
    # For buyer-to-seller conversion, use /buyer/onboarding/complete
    auth_header = request.headers['Authorization']
    token_val = auth_header.split(' ').last if auth_header.present? && auth_header.start_with?('Bearer ')

    if token_val.present? && token_val.include?('.')
      # JWT token provided, manually authenticate seller
      authenticate_seller
      return if performed?
    end

    seller = current_seller

    # Check if there is a pending registration token in the Authorization header
    if seller.nil?
      if token_val.present? && !token_val.include?('.')
        # A pending token is a 64-character hex string without dots (unlike JWT which has dots)
        cache_key = "pending_google_registration_#{token_val}"
        cached_data = Rails.cache.read(cache_key)
          
          if cached_data.present? && cached_data.is_a?(Hash) && cached_data[:role].to_s.casecmp?("seller")
            cached_data = cached_data.with_indifferent_access
            
            # Check if seller already exists by email
            seller = Seller.find_by(email: cached_data[:email])
            unless seller
              # Create the seller using the cached registration details
              base_name = cached_data[:name] || cached_data[:email].split('@').first
              base_username = base_name.to_s.downcase.gsub(/[^a-z0-9]/, '').first(15)
              username = base_username
              counter = 1
              while Seller.exists?(username: username) || Buyer.exists?(username: username)
                username = "#{base_username}#{counter}"
                counter += 1
              end

              seller = Seller.create!(
                fullname: cached_data[:name],
                email: cached_data[:email],
                username: username,
                provider: cached_data[:provider] || 'google',
                uid: cached_data[:uid],
                oauth_token: cached_data[:oauth_token],
                oauth_refresh_token: cached_data[:oauth_refresh_token],
                oauth_expires_at: cached_data[:oauth_expires_at],
                profile_picture: cached_data[:picture],
                phone_number: params[:profile][:phone_number]
              )
              
              # Delete from cache since registration is completed
              Rails.cache.delete(cache_key)
            end
          end
        end
      end
    
    unless seller
      return render json: { error: 'Unauthorized' }, status: :unauthorized
    end
    
    # Validate required profile fields
    required_profile_params = [:fullname, :phone_number, :enterprise_name, :location, :county_id, :sub_county_id, :description]
    missing_profile = required_profile_params.select { |p| params[:profile][p].blank? }
    
    if missing_profile.any?
      return render json: { 
        success: false, 
        errors: { profile: missing_profile.each_with_object({}) { |p, h| h[p] = ["is required"] } }
      }, status: :unprocessable_entity
    end

    # Validate required ad fields
    required_ad_params = [:title, :price, :category_id, :condition_id]
    missing_ad = required_ad_params.select { |p| params[:ad][p].blank? }
    
    if missing_ad.any?
      return render json: { 
        success: false, 
        errors: { ad: missing_ad.each_with_object({}) { |p, h| h[p] = ["is required"] } }
      }, status: :unprocessable_entity
    end

    # Process carbon_code string to carbon_code_id if provided
    carbon_code_param = params[:profile][:carbon_code]
    if carbon_code_param.present?
      carbon_code_record = CarbonCode.find_by("UPPER(TRIM(code)) = ?", carbon_code_param.to_s.strip.upcase)
      if carbon_code_record.nil?
        return render json: { success: false, errors: { carbon_code: ["Carbon code is invalid."] } }, status: :unprocessable_entity
      end
      unless carbon_code_record.valid_for_use?
        msg = carbon_code_record.expired? ? "This Carbon code has expired." : "This Carbon code has reached its usage limit."
        return render json: { success: false, errors: { carbon_code: [msg] } }, status: :unprocessable_entity
      end
      params[:profile][:carbon_code_id] = carbon_code_record.id
    end

    @seller = nil
    @ad = nil

    ActiveRecord::Base.transaction do
      @seller = seller
      
      # Update seller profile with onboarding data
      @seller.assign_attributes(
        fullname: params[:profile][:fullname],
        phone_number: params[:profile][:phone_number],
        secondary_phone_number: params[:profile][:secondary_phone_number],
        enterprise_name: params[:profile][:enterprise_name],
        location: params[:profile][:location],
        description: params[:profile][:description],
        county_id: params[:profile][:county_id],
        sub_county_id: params[:profile][:sub_county_id]
      )
      
      @seller.carbon_code_id = params[:profile][:carbon_code_id] if params[:profile][:carbon_code_id].present?
      
      unless @seller.save
        raise @seller.errors.full_messages.join(", ")
      end

      # After successful save, if carbon code was assigned and changed, increment usage
      if @seller.saved_change_to_carbon_code_id? && @seller.carbon_code_id.present?
        CarbonCode.find_by(id: @seller.carbon_code_id)&.increment!(:times_used)
      end
      
      # Ensure seller has a tier (assign Premium if not)
      unless @seller.seller_tier
        seller_tier = SellerTier.new(
          seller_id: @seller.id,
          tier_id: 4, # Premium
          duration_months: 6,
          expires_at: 6.months.from_now
        )
        unless seller_tier.save
          raise "Failed to assign seller tier"
        end
      end

      # Create a default main branch so the dashboard can load
      unless @seller.branches.exists?
        branch = @seller.branches.create(
          name: @seller.enterprise_name || "Main Branch",
          location: params[:profile][:location] || "Nairobi",
          is_main_branch: true
        )
        unless branch.persisted?
          raise "Failed to create default branch"
        end
      end
      
      # Process and upload images if present
      uploaded_media = []
      if params[:ad][:media].present?
        uploaded_media = process_and_upload_ad_images(params[:ad][:media])
      end

      # Create the first ad
      @ad = @seller.ads.build(
        title: params[:ad][:title],
        description: params[:ad][:description],
        price: params[:ad][:price],
        category_id: params[:ad][:category_id],
        condition: params[:ad][:condition_id],
        brand: params[:ad][:brand],
        manufacturer: params[:ad][:manufacturer],
        model: params[:ad][:model],
        item_length: params[:ad][:item_length],
        item_width: params[:ad][:item_width],
        item_height: params[:ad][:item_height],
        item_weight: params[:ad][:item_weight],
        subcategory_id: params[:ad][:subcategory_id],
        specifications: params[:ad][:specifications] || {},
        is_added_by_sales: false,
        media: uploaded_media
      )
      
      unless @ad.save
        raise @ad.errors.full_messages.join(", ")
      end
    end

    # Verify the transaction actually persisted before issuing a token
    unless Seller.exists?(@seller.id) && Ad.exists?(@ad.id)
      return render json: { success: false, error: "Onboarding failed. Please try again." }, status: :internal_server_error
    end

    # Post-transaction: Send welcome email
    begin
      WelcomeMailer.welcome_email(@seller).deliver_now
    rescue => e
    end

    # Generate seller token
    token = JsonWebToken.encode(
      seller_id: @seller.id,
      email: @seller.email,
      role: 'Seller',
      remember_me: true
    )

    render json: { 
      success: true, 
      message: "Onboarding completed successfully!",
      token: token,
      user: {
        id: @seller.id,
        email: @seller.email,
        role: 'Seller',
        name: @seller.fullname,
        username: @seller.username,
        enterprise_name: @seller.enterprise_name,
        profile_picture: @seller.profile_picture
      },
      ad: {
        id: @ad.id,
        title: @ad.title
      }
    }
  rescue ActiveRecord::Rollback => e
    render json: { success: false, error: e.message.presence || "Onboarding failed. Please try again." }, status: :unprocessable_entity
  rescue => e
    render json: { success: false, error: "Onboarding failed: #{e.message}" }, status: :internal_server_error
  end


  skip_before_action :authenticate_seller, only: [:pending_registration, :complete_onboarding]
private
  # DRY Upload Handler
  def handle_upload(file:, type:, max_size:, accepted_types:, processing_method:)
    raise "#{type.to_s.humanize} is too large" if file.size > max_size
    unless accepted_types.include?(file.content_type)
      raise "#{type.to_s.humanize} must be one of: #{accepted_types.join(', ')}"
    end
    send(processing_method, file)
  rescue => e
    nil
  end

  # Profile Picture Upload (direct upload, no processing)
  def process_and_upload_profile_picture(image)
    begin
      # Upload directly to Cloudinary without any processing
      uploaded = Cloudinary::Uploader.upload(image.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "profile_pictures",
        transformation: [
          { width: 400, height: 400, crop: "fill", gravity: "face" },
          { quality: "auto", fetch_format: "auto" }
        ]
      )
      uploaded["secure_url"]
    rescue => e
      Rails.logger.error "Error uploading profile picture: #{e.message}"
      nil
    end
  end

  # Document Upload (direct upload, no processing)
  def process_and_upload_document(document)
    begin
      # Upload directly to Cloudinary without any processing
      uploaded = Cloudinary::Uploader.upload(document.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "seller_documents",
        resource_type: "raw"
      )
      uploaded["secure_url"]
    rescue => e
      nil
    end
  end

  def process_and_upload_ad_images(images)
    uploaded_urls = []
    begin
      Array(images).each do |image|
        begin
          unless image.tempfile && File.exist?(image.tempfile.path)
            next
          end
          unless ENV['UPLOAD_PRESET'].present?
            raise "UPLOAD_PRESET not configured"
          end
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET'],
            format: nil,
            background: "transparent"
          )
          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
        end
      end
    rescue => e
    end
    uploaded_urls
  end
end
