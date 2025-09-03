class Admin::ProfilesController < ApplicationController
  before_action :authenticate_admin
  before_action :set_admin, only: [:show, :update]

  # GET /admin/profile
  def show
    render json: @admin
  end

  # PATCH/PUT /admin/profile
  def update
    if @admin.update(admin_params)
      render json: @admin
    else
      render json: @admin.errors, status: :unprocessable_entity
    end
  end

  # POST /admin/change-password
  def change_password
    # Check if the current password is correct
    if current_admin.authenticate(params[:currentPassword])
      # Check if new password matches confirmation
      if params[:newPassword] == params[:confirmPassword]
        # Update the password
        if current_admin.update(password: params[:newPassword])
          render json: { message: 'Password updated successfully' }, status: :ok
        else
          render json: { errors: current_admin.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'New password and confirmation do not match' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Current password is incorrect' }, status: :unauthorized
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
