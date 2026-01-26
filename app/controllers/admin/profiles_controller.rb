class Admin::ProfilesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_admin, only: [:show, :update]

  # GET /admin/profile
  def show
    admin_data = @admin.as_json
    admin_data[:has_password] = @admin.password_digest.present?
    render json: admin_data
  end

  # PATCH/PUT /admin/profile
  def update
    if @admin.update(admin_params)
      admin_data = @admin.as_json
      admin_data[:has_password] = @admin.password_digest.present?
      render json: admin_data
    else
      render json: @admin.errors, status: :unprocessable_entity
    end
  end

  # POST /admin/change-password
  def change_password
    # For Google OAuth users without a password, skip current password check
    is_google_user_without_password = current_admin.provider == 'google' && current_admin.password_digest.blank?
    
    # If user has a password, require current password
    if current_admin.password_digest.present?
      unless params[:currentPassword].present? && current_admin.authenticate(params[:currentPassword])
        render json: { error: 'Current password is incorrect' }, status: :unauthorized
        return
      end
    end
    
    # Check if new password matches confirmation
    if params[:newPassword] == params[:confirmPassword]
      # Update the password
      if current_admin.update(password: params[:newPassword])
        # Password changed successfully - session should be cleared on frontend
        # Return response indicating session invalidation
        render json: { 
          message: 'Password updated successfully',
          session_invalidated: true
        }, status: :ok
      else
        render json: { errors: current_admin.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
    end
  end

  private

  def set_admin
    @admin = current_admin
  end

  def admin_params
    params.permit(:fullname, :username, :email)
  end

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end

  def current_admin
    @current_user
  end
end
