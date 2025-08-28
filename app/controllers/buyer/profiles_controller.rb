# app/controllers/buyer/profiles_controller.rb
class Buyer::ProfilesController < ApplicationController
  before_action :authenticate_buyer

  # GET /buyer/profile
  def show
    render json: current_buyer
  end

  # PATCH/PUT /buyer/profile
  def update
    if current_buyer.update(buyer_params)
      render json: current_buyer
    else
      render json: current_buyer.errors, status: :unprocessable_entity
    end
  end

  # POST /buyer/change-password
  def change_password
    # Check if the current password is correct
    if current_buyer.authenticate(params[:currentPassword])
      # Check if new password matches confirmation
      if params[:newPassword] == params[:confirmPassword]
        # Update the password
        if current_buyer.update(password: params[:newPassword])
          render json: { message: 'Password updated successfully' }, status: :ok
        else
          render json: { errors: current_buyer.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Current password is incorrect' }, status: :unauthorized
    end
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
    params.permit(:fullname, :username, :phone_number, :email, :location, :zipcode, :fullname, :location, :gender, :city, :birthdate)
  end
end
