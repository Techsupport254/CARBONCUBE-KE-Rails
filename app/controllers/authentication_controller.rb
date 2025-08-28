class AuthenticationController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def login
    identifier = params[:email] || params[:identifier] || params[:authentication]&.[](:email)
    @user = find_user_by_identifier(identifier)

    if @user&.authenticate(params[:password])
      role = determine_role(@user)

      # ❌ Block login if the user is soft-deleted
      if (@user.is_a?(Buyer) || @user.is_a?(Seller)) && @user.deleted?
        render json: { errors: ['Your account has been deleted. Please contact support.'] }, status: :unauthorized
        return
      end

      # 🚫 Pilot restriction for sellers outside Nairobi (only if pilot phase is enabled)
      if Rails.application.config.pilot_phase_enabled && role == 'seller' && @user.county&.county_code.to_i != 47
        render json: {
          errors: ['Access restricted during pilot phase. Only Nairobi-based sellers can log in.']
        }, status: :forbidden
        return
      end

      user_response = {
        id: @user.id,
        email: @user.email,
        role: role
      }
      
      # Add name fields based on user type
      if @user.respond_to?(:fullname) && @user.fullname.present?
        user_response[:name] = @user.fullname
      elsif @user.respond_to?(:username) && @user.username.present?
        user_response[:name] = @user.username
      end
      
      user_response[:phone_number] = @user.phone_number if @user.is_a?(Rider)
      user_response[:id_number] = @user.id_number if @user.is_a?(Rider)

      token = JsonWebToken.encode(user_id: @user.id, role: role)
      render json: { token: token, user: user_response }, status: :ok
    else
      render json: { errors: ['Invalid login credentials'] }, status: :unauthorized
    end
  end

  private

  def find_user_by_identifier(identifier)
    if identifier.include?('@')
      # Assume it's an email if it contains '@'
      Buyer.find_by(email: identifier) ||
      Seller.find_by(email: identifier) ||
      Admin.find_by(email: identifier) ||
      SalesUser.find_by(email: identifier) ||
      Rider.find_by(email: identifier)
    elsif identifier.match?(/\A\d{10}\z/)
      # Assume phone number if it’s 10 digits
      Rider.find_by(phone_number: identifier)
    else
      # Otherwise, assume it’s an ID number
      Rider.find_by(id_number: identifier)
    end
  end

  def determine_role(user)
    case user
    when Buyer then 'buyer'
    when Seller then 'seller'
    when Admin then 'admin'
    when SalesUser then 'sales'
    when Rider then 'rider'
    else 'unknown'
    end
  end
end
