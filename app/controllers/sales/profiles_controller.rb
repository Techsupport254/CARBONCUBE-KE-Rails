class Sales::ProfilesController < ApplicationController
  before_action :authenticate_sales_user
  before_action :set_sales_user, only: [:show, :update]

  # GET /sales/profile
  def show
    sales_user_data = @sales_user.as_json
    sales_user_data[:role] = 'sales'
    sales_user_data[:has_password] = @sales_user.password_digest.present?
    render json: sales_user_data
  end

  # PATCH/PUT /sales/profile
  def update
    if @sales_user.update(sales_user_params)
      sales_user_data = @sales_user.as_json
      sales_user_data[:has_password] = @sales_user.password_digest.present?
      render json: sales_user_data
    else
      render json: @sales_user.errors, status: :unprocessable_entity
    end
  end

  # POST /sales/profile/change-password
  def change_password
    # For Google OAuth users without a password, skip current password check
    is_google_user_without_password = current_sales_user.provider == 'google' && current_sales_user.password_digest.blank?
    
    # If user has a password, require current password
    if current_sales_user.password_digest.present?
      unless params[:currentPassword].present? && current_sales_user.authenticate(params[:currentPassword])
        render json: { error: 'Current password is incorrect' }, status: :unauthorized
        return
      end
    end
    
    # Check if new password matches confirmation
    if params[:newPassword] == params[:confirmPassword]
      # Update the password
      if current_sales_user.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: { 
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_sales_user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  private

  def set_sales_user
    @sales_user = current_sales_user
  end

  def sales_user_params
    params.permit(:fullname, :email)
  end

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_sales_user
    @current_sales_user
  end
end

