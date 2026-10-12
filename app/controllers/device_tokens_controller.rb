class DeviceTokensController < ApplicationController
  before_action :set_current_user_optional, only: [:create, :ping_push]
  before_action :authenticate_request, only: [:destroy]

  # POST /device_tokens
  # Supports both authenticated users and unauthenticated guests.
  # When unauthenticated: registers token as a guest device (for broadcasts, deals, promotions).
  # When authenticated: associates token with @current_user.
  def create
    token = params[:token].to_s.strip
    platform = params[:platform].to_s.strip

    if token.blank?
      render json: { error: 'Token is required' }, status: :unprocessable_entity
      return
    end

    # Normalize platform
    platform = platform.downcase if platform.present?
    platform = 'android' unless %w[ios android web].include?(platform)

    # Upsert the device token
    device_token = DeviceToken.find_or_initialize_by(token: token)
    
    # Associate user if logged in, otherwise keep/set as guest (nil)
    if @current_user
      device_token.user = @current_user
    elsif device_token.new_record?
      device_token.user = nil
    end

    device_token.platform = platform if platform.present?

    if device_token.save
      render json: {
        message: 'Device token registered successfully',
        platform: device_token.platform,
        is_guest: device_token.guest?,
        user_id: device_token.user_id
      }, status: :ok
    else
      render json: { error: device_token.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /device_tokens/destroy or DELETE /device_tokens
  # Unlinks the device token from the current user so it reverts to guest mode
  # (retaining broadcast/deal capability) or removes it completely.
  def destroy
    token = params[:token].to_s.strip

    if token.blank?
      render json: { error: 'Token is required' }, status: :unprocessable_entity
      return
    end

    if @current_user
      dt = DeviceToken.find_by(token: token, user: @current_user)
      # Revert token to guest mode so the device can still receive announcements & promotions
      dt&.update(user_id: nil, user_type: nil)
    else
      DeviceToken.where(token: token).destroy_all
    end

    head :no_content
  end

  # POST /device_tokens/ping_push
  # Sends a real FCM push notification to the given token to verify the pipeline.
  # Works for both logged-in users and guest devices.
  # Accepts { token: "fcm_token_string", platform: "android"|"ios" } in request body.
  def ping_push
    target_token = params[:token].presence

    if target_token.blank? && @current_user
      # Fall back to first stored token for this user
      target_token = DeviceToken.where(user: @current_user).order(created_at: :desc).pluck(:token).first
    end

    if target_token.blank?
      render json: {
        success: false,
        error: 'No FCM token provided. Pass { token: "..." } or log in on a registered device.'
      }, status: :unprocessable_entity
      return
    end

    # Upsert token record best-effort
    device_token = DeviceToken.find_or_initialize_by(token: target_token)
    device_token.user     = @current_user if @current_user
    device_token.platform = params[:platform] if params[:platform].present?
    device_token.save

    payload = {
      title: '🔔 Push Notification Test',
      body:  'Your push notifications are working correctly! 🎉 Carbon Cube alerts are active.',
      data: {
        type:    'ping',
        sent_at: Time.current.iso8601,
        user_id: @current_user&.id.to_s
      }
    }

    result = PushNotificationService.send_notification_with_details([target_token], payload)
    success = result[:success]

    if success
      render json: {
        success: true,
        message: 'Test push notification sent! Check your device notification tray.',
        token_prefix: target_token.first(20) + '...',
        credential_source: result[:credential_source],
        success_count: result[:success_count],
        failure_count: result[:failure_count]
      }, status: :ok
    else
      first_failure = Array(result[:failures]).first || {}
      detailed_error = first_failure[:message].presence || result[:message].presence ||
        'FCM returned an error. Check server logs for details.'

      render json: {
        success: false,
        error: detailed_error,
        token_prefix: target_token.first(20) + '...',
        fcm_status: first_failure[:fcm_status],
        fcm_error_code: first_failure[:error_code],
        firebase_project_id: result[:project_id],
        credential_source: result[:credential_source]
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "DeviceTokensController#ping_push error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    render json: { success: false, error: "Internal error: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_current_user_optional
    auth_header = request.headers['Authorization']
    if auth_header.present?
      @current_user = AuthorizeApiRequest.new(request.headers).result rescue nil
    end
  end
end
