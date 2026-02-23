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

  # POST /device_tokens/ping_push
  # Sends a real FCM push notification to the given token to verify the pipeline.
  # Accepts { token: "fcm_token_string" } in the request body.
  # If token is omitted, falls back to ANY registered token for the current user.
  def ping_push
    # Determine which FCM token to ping
    target_token = params[:token].presence

    if target_token.blank?
      # Fall back to first stored token for this user
      target_token = DeviceToken.where(user: @current_user).order(created_at: :desc).pluck(:token).first
    end

    if target_token.blank?
      render json: {
        success: false,
        error: 'No FCM token found. Make sure you are logged in and have granted notification permission on the device.'
      }, status: :unprocessable_entity
      return
    end

    # Upsert the token so it is definitely stored for this user
    device_token = DeviceToken.find_or_initialize_by(token: target_token)
    device_token.user     = @current_user
    device_token.platform = params[:platform] if params[:platform].present?
    device_token.save # Best-effort; don't block on validation errors

    payload = {
      title: '🔔 Push Notification Test',
      body:  'Your push notifications are working correctly! 🎉',
      data: {
        type:    'ping',
        sent_at: Time.current.iso8601,
        user_id: @current_user.id.to_s
      }
    }

    success = PushNotificationService.send_notification([target_token], payload)

    if success
      render json: {
        success: true,
        message: 'Test push notification sent! Check your device notification tray.',
        token_prefix: target_token.first(20) + '...'
      }, status: :ok
    else
      render json: {
        success: false,
        error: 'FCM returned an error. Check server logs for details. Common causes: invalid token, Firebase credentials missing, or the app is re-installed (stale token).',
        token_prefix: target_token.first(20) + '...'
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "DeviceTokensController#ping_push error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { success: false, error: "Internal error: #{e.message}" }, status: :internal_server_error
  end
end
