class Buyer::BuyersController < ApplicationController
  before_action :set_buyer, only: [:show, :update]
  before_action :authenticate_buyer, only: [:identify, :show, :update, :destroy]
  before_action :set_default_format

  # GET /buyer/identify
  def identify
    render json: { buyer_id: current_buyer.id }
  end

  # GET /buyers/:id
  def show
    render json: current_buyer
  end

  # POST /buyers/signup
  def create
    logger.debug "Buyer Params Received: #{buyer_params.inspect}"

    buyer_email = buyer_params[:email].downcase.strip
    otp_code = params[:otp]

    if Seller.exists?(email: buyer_email)
      render json: { errors: ['Email is already in use by a seller'] }, status: :unprocessable_entity
    elsif Buyer.exists?(email: buyer_email)
      render json: { errors: ['Email has already been taken'] }, status: :unprocessable_entity
    elsif Buyer.exists?(username: buyer_params[:username])
      render json: { errors: ['Username has already been taken'] }, status: :unprocessable_entity
    else
      # OTP verification is now optional for buyer signup
      # Users can verify their email later if they choose
      otp_record = nil
      if otp_code.present?
        otp_record = EmailOtp.find_by(email: buyer_email, otp_code: otp_code)
        
        if otp_record.nil?
          logger.error "Invalid OTP for email: #{buyer_email}"
          return render json: { errors: ['Invalid OTP'] }, status: :unauthorized
        elsif otp_record.verified == true
          logger.error "OTP already used for email: #{buyer_email}"
          return render json: { errors: ['OTP has already been used'] }, status: :unauthorized
        elsif otp_record.expires_at.present? && otp_record.expires_at <= Time.now
          logger.error "OTP expired for email: #{buyer_email}"
          return render json: { errors: ['OTP has expired'] }, status: :unauthorized
        end
      end

      @buyer = Buyer.new(buyer_params)

      if @buyer.save
        # Email verification is optional - users can verify their email later if they choose
        # OTP is validated if provided but not automatically marked as verified

        # Send welcome email
        begin
          WelcomeMailer.welcome_email(@buyer).deliver_now
          puts "✅ Welcome email sent to: #{@buyer.email}"
        rescue => e
          puts "❌ Failed to send welcome email: #{e.message}"
          # Don't fail the registration if email fails
        end
        
        # New buyers get remember_me by default for better user experience
        token = JsonWebToken.encode(user_id: @buyer.id, email: @buyer.email, role: 'Buyer', remember_me: true)
        render json: { token: token, buyer: @buyer }, status: :created
      else
        logger.debug "Buyer Errors: #{@buyer.errors.full_messages}"
        render json: { errors: @buyer.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
  
  # PATCH/PUT /buyers/:id
  def update
    if current_buyer.update(buyer_params)
      render json: current_buyer
    else
      render json: current_buyer.errors, status: :unprocessable_entity
    end
  end

  # DELETE /buyers/:id
  def destroy
    if current_buyer.nil?
      Rails.logger.error("Current buyer is nil during account deletion.")
      render json: { error: 'Not Authorized' }, status: :unauthorized
      return
    end

    if current_buyer.update(deleted: true)
      head :no_content
    else
      render json: { error: 'Failed to delete account' }, status: :unprocessable_entity
    end
  end


  private

  def set_buyer
    @buyer = Buyer.find(params[:id])
  end

  def buyer_params
    permitted = params.require(:buyer).permit(
      :fullname, :username, :email, :phone_number, :password, 
      :password_confirmation, :age_group_id, :zipcode, :city, :gender, 
      :location, :income_id, :sector_id, :education_id, :employment_id,
      :county_id, :sub_county_id
    )

    # Convert blank string values to nil
    permitted.each { |key, value| permitted[key] = nil if value == "" }

    permitted
  end


  def set_default_format
    request.format = :json unless params[:format]
  end

  def authenticate_buyer
    @current_buyer = BuyerAuthorizeApiRequest.new(request.headers).result

    if @current_buyer.nil?
      render json: { error: 'Not Authorized' }, status: :unauthorized
    elsif @current_buyer.deleted?
      render json: { error: 'Account has been deleted' }, status: :unauthorized
    end
  end

  def current_buyer
    @current_buyer
  end
end
