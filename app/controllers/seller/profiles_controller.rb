class Seller::ProfilesController < ApplicationController
  before_action :authenticate_seller
  before_action :set_seller, only: [:show, :update]

  # GET /seller/profile
  def show
    render json: @seller
  end

  # PATCH/PUT /seller/profile
  def update
    if @seller.update(seller_params)
      render json: @seller
    else
      render json: @seller.errors, status: :unprocessable_entity
    end
  end

  # POST /seller/change-password
  def change_password
    # Check if the current password is correct
    if current_seller.authenticate(params[:currentPassword])
      # Check if new password matches confirmation
      if params[:newPassword] == params[:confirmPassword]
        # Update the password
        if current_seller.update(password: params[:newPassword])
          render json: { message: 'Password updated successfully' }, status: :ok
        else
          render json: { errors: current_seller.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Current password is incorrect' }, status: :unauthorized
    end
  end

  private

  def set_seller
    @seller = current_seller
  end

  def seller_params
    params.permit(:fullname, :phone_number, :email, :enterprise_name, :location, :password, :password_confirmation, :business_registration_number, :gender, :city, :birthdate, :zipcode, :username)
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
end
