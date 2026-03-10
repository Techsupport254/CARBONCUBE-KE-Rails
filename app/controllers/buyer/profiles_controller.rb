# app/controllers/buyer/profiles_controller.rb
require 'fileutils'

class Buyer::ProfilesController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/profile
  def show
    buyer_data = current_buyer.as_json
    buyer_data[:profile_completion_percentage] = current_buyer.profile_completion_percentage
    # Avoid using cached profile pictures - return nil for cached URLs
    if buyer_data[:profile_picture]&.start_with?('/cached_profile_pictures/')
      buyer_data[:profile_picture] = nil
    end
    # Check if email is verified
    # Google OAuth users are treated as automatically verified
    if current_buyer.respond_to?(:provider) && current_buyer.provider.to_s.downcase == 'google'
      email_verified = true
    else
      email_verified = EmailOtp.exists?(email: current_buyer.email, verified: true)
    end
    buyer_data[:email_verified] = email_verified
    # Check if user has a password set
    # password_digest will be nil or empty string for OAuth users who haven't set a password
    # It will be present (a bcrypt hash) for users who have set a password
    buyer_data[:has_password] = current_buyer.password_digest.present? && !current_buyer.password_digest.to_s.strip.empty?
    # Ensure timestamps are included
    buyer_data[:created_at] = current_buyer.created_at
    buyer_data[:updated_at] = current_buyer.updated_at
    render json: buyer_data
  end

  # PATCH/PUT /buyer/profile
  def update
    begin
      uploaded_profile_picture_url = nil
      
      # Handle profile picture upload if present
      if params[:profile_picture].present?
        pic = params[:profile_picture]
        
        # Check if it's actually a file object
        unless pic.respond_to?(:original_filename)
          Rails.logger.error "Profile picture is not a file object: #{pic.class}"
          return render json: { error: "Invalid file format" }, status: :unprocessable_entity
        end
        
        Rails.logger.info "📸 Processing profile picture: #{pic.original_filename}"

        uploaded_profile_picture_url = handle_upload(
          file: pic,
          type: :profile_picture,
          max_size: 2.megabytes,
          accepted_types: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
          processing_method: :process_and_upload_profile_picture
        )

        if uploaded_profile_picture_url.nil?
          Rails.logger.error "Profile picture upload failed"
          return render json: { error: "Failed to upload profile picture" }, status: :unprocessable_entity
        end

        Rails.logger.info "Profile picture uploaded successfully: #{uploaded_profile_picture_url}"
      end

      # Only update fields that are provided and valid
      update_params = buyer_params.reject { |k, v| v.blank? }
      
      # Remove any unexpected fields that might cause issues
      unexpected_fields = ['created_at', 'updated_at', 'id']
      unexpected_fields.each { |field| update_params.delete(field) }
      
      # Additional filtering for empty strings and null values
      update_params = update_params.reject { |k, v| v.nil? || v.to_s.strip.empty? }

      # Add the uploaded URL if available
      update_params[:profile_picture] = uploaded_profile_picture_url if uploaded_profile_picture_url
      
      # Track if phone is being added (for welcome WhatsApp when user didn't have phone from OAuth)
      phone_number_before = current_buyer.phone_number
      phone_being_added = update_params[:phone_number].present? && phone_number_before.blank?
      update_params[:phone_provided_by_oauth] = false if phone_being_added
      
      if current_buyer.update(update_params)
        # Send welcome WhatsApp when phone was just added (e.g. OAuth user completing signup modal)
        if phone_being_added && current_buyer.phone_number.present? && !current_buyer.phone_provided_by_oauth
          Rails.logger.info "📱 Sending welcome WhatsApp after phone added via profile - buyer #{current_buyer.email}"
          WhatsAppNotificationService.send_welcome_message_async(current_buyer)
        end
        buyer_data = current_buyer.as_json
        buyer_data[:profile_completion_percentage] = current_buyer.profile_completion_percentage
        # Avoid using cached profile pictures - return nil for cached URLs
        if buyer_data[:profile_picture]&.start_with?('/cached_profile_pictures/')
          buyer_data[:profile_picture] = nil
        end
        # Check if email is verified
        # Google OAuth users are treated as automatically verified
        if current_buyer.respond_to?(:provider) && current_buyer.provider.to_s.downcase == 'google'
          email_verified = true
        else
          email_verified = EmailOtp.exists?(email: current_buyer.email, verified: true)
        end
        buyer_data[:email_verified] = email_verified
        # Check if user has a password set
        # password_digest will be nil or empty string for OAuth users who haven't set a password
        # It will be present (a bcrypt hash) for users who have set a password
        buyer_data[:has_password] = current_buyer.password_digest.present? && !current_buyer.password_digest.to_s.strip.empty?
        # Ensure timestamps are included
        buyer_data[:created_at] = current_buyer.created_at
        buyer_data[:updated_at] = current_buyer.updated_at
        render json: buyer_data
      else
        Rails.logger.error "Update failed: #{current_buyer.errors.full_messages}"
        render json: current_buyer.errors, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Unexpected error in update: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "An unexpected error occurred" }, status: :internal_server_error
    end
  end

  # POST /buyer/change-password
  def change_password
    # If user has a password, require current password
    if current_buyer.password_digest.present?
      # Check if currentPassword was provided
      unless params[:currentPassword].present?
        render json: { error: 'Current password is required' }, status: :unauthorized
        return
      end
      
      # Authenticate the current password
      unless current_buyer.authenticate(params[:currentPassword])
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
      if current_buyer.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: { 
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_buyer.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  # POST /buyer/profile/request-verification
  def request_verification
    email = current_buyer.email
    fullname = current_buyer.fullname
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
      Rails.logger.info "✅ Verification OTP email sent successfully to #{email}"
    rescue => e
      Rails.logger.error "❌ Failed to send verification OTP email: #{e.message}"
      # Don't fail the request if email fails
    end

    response = { message: "Verification code sent to your email" }
    render json: response, status: :ok
  end

  # POST /buyer/profile/verify-email
  def verify_email
    email = current_buyer.email
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

  # POST /buyer/profile/upgrade_to_seller
  def upgrade_to_seller
    # 1. Check if user is already a seller
    if Seller.exists?(email: current_buyer.email)
      return render json: { 
        success: false, 
        error: "You are already registered as a seller with this email." 
      }, status: :unprocessable_entity
    end

    # 2. Validate required seller fields
    required_params = [:enterprise_name, :location, :description, :county_id, :sub_county_id]
    missing = required_params.select { |p| params[p].blank? }
    
    if missing.any?
      return render json: { 
        success: false, 
        errors: missing.each_with_object({}) { |p, h| h[p] = ["is required for sellers"] }
      }, status: :unprocessable_entity
    end

    buyer = current_buyer
    @seller = nil

    # 3. Run the entire upgrade inside a transaction so it's atomic.
    #    If ANY step fails, the whole thing rolls back cleanly.
    ActiveRecord::Base.transaction do
      # --- 3a. Create the Seller record ---
      # NOTE: We do NOT pass password_digest here because has_secure_password intercepts
      # the assignment and still validates the virtual `password` attribute.
      # Instead we save with a temp random password and then stamp the real digest directly
      # via update_column (which skips all validations and callbacks).
      temp_password = SecureRandom.hex(32)
      @seller = Seller.new(
        fullname:               buyer.fullname,
        email:                  buyer.email.downcase.strip,
        phone_number:           buyer.phone_number,
        secondary_phone_number: buyer.secondary_phone_number,
        username:               buyer.username,
        password:               temp_password,
        password_confirmation:  temp_password,
        provider:               buyer.respond_to?(:provider)               ? buyer.provider               : nil,
        uid:                    buyer.respond_to?(:uid)                    ? buyer.uid                    : nil,
        oauth_token:            buyer.respond_to?(:oauth_token)            ? buyer.oauth_token            : nil,
        oauth_refresh_token:    buyer.respond_to?(:oauth_refresh_token)    ? buyer.oauth_refresh_token    : nil,
        oauth_expires_at:       buyer.respond_to?(:oauth_expires_at)       ? buyer.oauth_expires_at       : nil,
        phone_provided_by_oauth: buyer.respond_to?(:phone_provided_by_oauth) ? buyer.phone_provided_by_oauth : nil,
        enterprise_name:        params[:enterprise_name],
        location:               params[:location],
        description:            params[:description],
        county_id:              params[:county_id],
        sub_county_id:          params[:sub_county_id],
        profile_picture:        buyer.profile_picture,
        age_group_id:           buyer.age_group_id,
        gender:                 buyer.gender,
        city:                   buyer.city || params[:city],
        zipcode:                buyer.zipcode || params[:zipcode]
      )

      @seller.category_ids = params[:category_ids] if params[:category_ids].present?

      unless @seller.save
        Rails.logger.error "Seller creation during upgrade failed: #{@seller.errors.full_messages.inspect}"
        raise ActiveRecord::Rollback, @seller.errors.full_messages.join(", ")
      end

      # Overwrite temp password with the buyer's real password_digest (skips all validations)
      if buyer.password_digest.present?
        @seller.update_column(:password_digest, buyer.password_digest)
      end

      # --- 3b. Assign Premium tier (6 months) ---
      seller_tier = SellerTier.new(
        seller_id:       @seller.id,
        tier_id:         4, # Premium
        duration_months: 6,
        expires_at:      6.months.from_now
      )
      unless seller_tier.save
        Rails.logger.error "Failed to create SellerTier during upgrade: #{seller_tier.errors.full_messages.inspect}"
        raise ActiveRecord::Rollback, "Failed to assign seller tier"
      end

      # --- 3c. Migrate all buyer-linked records to the new seller ---
      conn = ActiveRecord::Base.connection

      # Tables with a direct buyer_id foreign key
      [
        { table: :click_events,    fk: :buyer_id },
        { table: :wish_lists,      fk: :buyer_id },
        { table: :cart_items,      fk: :buyer_id },
        { table: :reviews,         fk: :buyer_id },
        { table: :conversations,   fk: :buyer_id },
        { table: :ad_searches,     fk: :buyer_id },
      ].each do |mapping|
        rows = conn.execute("UPDATE #{mapping[:table]} SET #{mapping[:fk]} = '#{@seller.id}' WHERE #{mapping[:fk]} = '#{buyer.id}'")
        Rails.logger.info "✅  Migrated #{mapping[:table]} (buyer_id) -> seller #{@seller.id}"
      end

      # Polymorphic: messages (sender_type = 'Buyer')
      conn.execute("UPDATE messages SET sender_id = '#{@seller.id}', sender_type = 'Seller' WHERE sender_id = '#{buyer.id}' AND sender_type = 'Buyer'")
      Rails.logger.info "✅  Migrated messages -> Seller sender"

      # Polymorphic: password_otps (otpable_type = 'Buyer')
      conn.execute("UPDATE password_otps SET otpable_id = '#{@seller.id}', otpable_type = 'Seller' WHERE otpable_id = '#{buyer.id}' AND otpable_type = 'Buyer'")
      Rails.logger.info "✅  Migrated password_otps -> Seller"

      # Polymorphic: device_tokens (user_type / tokenable_type)
      begin
        conn.execute("UPDATE device_tokens SET user_id = '#{@seller.id}', user_type = 'Seller' WHERE user_id = '#{buyer.id}' AND user_type = 'Buyer'")
        Rails.logger.info "✅  Migrated device_tokens -> Seller"
      rescue => e
        Rails.logger.warn "⚠️  device_tokens migration skipped: #{e.message}"
      end

      # --- 3d. Destroy the buyer record (hard delete — they are now a seller) ---
      buyer.destroy!
      Rails.logger.info "✅  Buyer #{buyer.id} destroyed — fully migrated to Seller #{@seller.id}"
    end

    # --- 4. Post-transaction side effects ---
    begin
      WelcomeMailer.welcome_email(@seller).deliver_now
    rescue => e
      Rails.logger.error "Failed to send welcome email during upgrade: #{e.message}"
    end

    token = JsonWebToken.encode(
      seller_id: @seller.id,
      email:     @seller.email,
      role:      'Seller',
      remember_me: true
    )

    render json: { 
      success: true, 
      message: "Successfully upgraded to seller account!",
      token: token,
      user: {
        id:               @seller.id,
        email:            @seller.email,
        role:             'Seller',
        name:             @seller.fullname,
        username:         @seller.username,
        enterprise_name:  @seller.enterprise_name,
        profile_picture:  @seller.profile_picture
      }
    }, status: :created

  rescue ActiveRecord::Rollback => e
    render json: { success: false, error: e.message.presence || "Upgrade failed. Please try again." }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Unexpected error during upgrade: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { success: false, error: "Upgrade failed: #{e.message}" }, status: :internal_server_error
  end

  

  private

  def authenticate_buyer
    @current_user = BuyerAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Buyer)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_user
  end

  # Updated buyer_params to permit top-level parameters
  def buyer_params
    params.permit(:fullname, :username, :phone_number, :secondary_phone_number, :email, :location, :zipcode, :gender, :city, 
                  :county_id, :sub_county_id, :age_group_id, :income_id, :employment_id, 
                  :education_id, :sector_id, :phone_provided_by_oauth)
  end

  # DRY Upload Handler
  def handle_upload(file:, type:, max_size:, accepted_types:, processing_method:)
    raise "#{type.to_s.humanize} is too large" if file.size > max_size
    unless accepted_types.include?(file.content_type)
      raise "#{type.to_s.humanize} must be one of: #{accepted_types.join(', ')}"
    end
    send(processing_method, file)
  rescue => e
    Rails.logger.error "Upload failed (#{type}): #{e.message}"
    nil
  end

  # Profile Picture Upload (direct upload, no processing)
  def process_and_upload_profile_picture(image)
    begin
      # Upload directly to Cloudinary without any processing
      uploaded = Cloudinary::Uploader.upload(image.tempfile.path,
        upload_preset: ENV['UPLOAD_PRESET'],
        folder: "buyer_profile_pictures",
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
end
