class DeviceTokensController < ApplicationController
  before_action :authenticate_request

  def create
    token = params[:token]
    platform = params[:platform]

    if token.blank?
      render json: { error: 'Token is required' }, status: :unprocessable_entity
      return
    end

    # Find or create the device token for the current user
    # Note: DeviceToken should probably be unique per token.
    # If the token exists for another user, it means the device was logout/login with different user.
    # So we find by token first.
    device_token = DeviceToken.find_or_initialize_by(token: token)
    
    # Update the user association
    device_token.user = @current_user
    device_token.platform = platform if platform.present?

    if device_token.save
      render json: { message: 'Device token registered successfully' }, status: :ok
    else
      render json: { error: device_token.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
