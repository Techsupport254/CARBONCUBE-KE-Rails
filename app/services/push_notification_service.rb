require 'googleauth'
require 'stringio'
require 'pathname'

class PushNotificationService
  include HTTParty
  base_uri 'https://fcm.googleapis.com'

  FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'.freeze

  def self.send_notification(tokens, notification_payload, notifiable = nil)
    result = send_notification_with_details(tokens, notification_payload, notifiable)
    result[:success]
  end

  def self.send_notification_with_details(tokens, notification_payload, notifiable = nil)
    # tokens: array of strings or a single string
    tokens = Array(tokens).compact.uniq
    return { success: false, error: 'NO_TOKENS', message: 'No tokens provided', failures: [] } if tokens.empty?

    project_id = get_project_id
    unless project_id.present?
      bundle = firebase_credentials_bundle
      Rails.logger.error "PushNotificationService: Missing Firebase project_id. " \
                         "Source: #{bundle[:source]}, " \
                         "Credentials Present: #{bundle[:credentials].present?}, " \
                         "Is Hash: #{bundle[:credentials].is_a?(Hash)}, " \
                         "Details: #{bundle[:credentials].is_a?(Hash) ? bundle[:credentials].keys.join(',') : 'N/A'}"
      return {
        success: false,
        error: 'MISSING_PROJECT_ID',
        message: 'Firebase project_id is missing from credentials.',
        failures: [],
        credential_source: bundle[:source],
        project_id: nil
      }
    end

    access_token = get_access_token
    
    unless access_token
      Rails.logger.error "PushNotificationService: Failed to get access token."
      return {
        success: false,
        error: 'ACCESS_TOKEN_FAILED',
        message: 'Failed to obtain Firebase access token.',
        failures: [],
        credential_source: firebase_credentials_source,
        project_id: project_id
      }
    end

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    success_count = 0
    failures = []
    
    tokens.each do |token|
      body = {
        message: {
          token: token,
          notification: {
            title: notification_payload[:title],
            body: notification_payload[:body]
          },
          data: notification_payload[:data]&.transform_values(&:to_s) || {},
          # Android: must specify channel_id for Android 8+, otherwise notification is silently dropped.
          # icon must be a drawable resource name in the app (ic_launcher is always available).
          android: {
            priority: 'high',
            notification: {
              channel_id: 'default',
              icon:       'ic_launcher',
              color:      '#FACC15'
            }
          },
          # iOS: ensure alert is shown even in foreground
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1
              }
            },
            headers: {
              'apns-priority' => '10'
            }
          }
        }
      }

      response = post("/v1/projects/#{project_id}/messages:send", headers: headers, body: body.to_json)
      
      if response&.success?
        success_count += 1
        Rails.logger.info "PushNotificationService: Notification sent to #{token}. Response: #{response.body}"
      else
        parsed_error = parse_fcm_error(response)
        failures << {
          token_prefix: mask_token(token),
          status_code: response&.code,
          fcm_status: parsed_error[:fcm_status],
          error_code: parsed_error[:error_code],
          message: parsed_error[:message]
        }

        if parsed_error[:error_code] == 'UNREGISTERED'
          DeviceToken.where(token: token).delete_all
          Rails.logger.info "PushNotificationService: Removed stale device token #{mask_token(token)}"
        end

        Rails.logger.error(
          "PushNotificationService: Failed to send to #{token}. " \
          "Status: #{response&.code}, FCM status: #{parsed_error[:fcm_status]}, " \
          "errorCode: #{parsed_error[:error_code]}, message: #{parsed_error[:message]}"
        )
      end
    end

    # Persist the notification in the database for history (using first token for recipient info)
    first_token = tokens.first
    device_token = DeviceToken.find_by(token: first_token)
    
    if device_token&.user
      begin
        Notification.create!(
          recipient: device_token.user,
          notifiable: notifiable,
          title: notification_payload[:title],
          body: notification_payload[:body],
          data: notification_payload[:data],
          status: success_count > 0 ? 'sent' : 'failed'
        )
      rescue => e
        Rails.logger.error "PushNotificationService: Failed to create Notification record: #{e.message}"
      end
    end

    {
      success: success_count > 0,
      project_id: project_id,
      credential_source: firebase_credentials_source,
      success_count: success_count,
      failure_count: tokens.length - success_count,
      failures: failures
    }
  rescue => e
    Rails.logger.error "PushNotificationService: Exception #{e.message}"
    { success: false, error: 'EXCEPTION', message: e.message, failures: [] }
  end

  private

  def self.parse_fcm_error(response)
    default_message = response&.body.to_s
    parsed = {}
    begin
      parsed = JSON.parse(default_message)
    rescue JSON::ParserError
      parsed = {}
    end

    error_obj = parsed['error'] || {}
    details = Array(error_obj['details'])
    fcm_detail = details.find { |d| d.is_a?(Hash) && d['errorCode'].present? } || {}

    {
      fcm_status: error_obj['status'],
      error_code: fcm_detail['errorCode'],
      message: error_obj['message'] || default_message
    }
  end

  def self.mask_token(token)
    return '' if token.blank?
    return token if token.length <= 20
    "#{token[0, 12]}...#{token[-6, 6]}"
  end

  def self.get_access_token
    credentials = firebase_credentials
    unless credentials.present?
      Rails.logger.error(
        'PushNotificationService: Firebase credentials missing. Set FIREBASE_SERVICE_ACCOUNT_PATH ' \
        'or FIREBASE_SERVICE_ACCOUNT_JSON (or provide config/firebase-service-account.json for local dev).'
      )
      return nil
    end

    begin
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(credentials.to_json),
        scope: FCM_SCOPE
      )
      return authorizer.fetch_access_token!['access_token']
    rescue => e
      Rails.logger.error "PushNotificationService: Failed to get access token from Firebase credentials: #{e.message}"
    end

    nil
  end

  def self.get_project_id
    explicit_project_id = ENV['FIREBASE_PROJECT_ID'].to_s.strip
    return explicit_project_id if explicit_project_id.present?

    credentials = firebase_credentials
    return credentials['project_id'] if credentials.is_a?(Hash) && credentials['project_id'].present?

    nil
  end

  def self.parse_service_account_json(raw_json)
    normalized = raw_json.to_s.strip
    # Handle env values wrapped in single quotes by shell tooling.
    if (normalized.start_with?("'") && normalized.end_with?("'")) ||
       (normalized.start_with?('"') && normalized.end_with?('"'))
      normalized = normalized[1..-2]
    end

    parsed = JSON.parse(normalized)
    # Handles env values that are double-encoded JSON strings.
    parsed = JSON.parse(parsed) if parsed.is_a?(String)
    parsed if parsed.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end

  def self.firebase_credentials
    firebase_credentials_bundle[:credentials]
  end

  def self.firebase_credentials_source
    firebase_credentials_bundle[:source]
  end

  def self.firebase_credentials_bundle
    path_from_env = ENV['FIREBASE_SERVICE_ACCOUNT_PATH'].to_s.strip
    if path_from_env.present?
      path = Pathname.new(path_from_env)
      if path.file?
        begin
          parsed = JSON.parse(path.read)
          return { credentials: parsed, source: 'FIREBASE_SERVICE_ACCOUNT_PATH' } if parsed.is_a?(Hash)
        rescue => e
          Rails.logger.error "PushNotificationService: Failed to parse FIREBASE_SERVICE_ACCOUNT_PATH JSON: #{e.message}"
        end
      else
        Rails.logger.error "PushNotificationService: FIREBASE_SERVICE_ACCOUNT_PATH file not found at #{path_from_env}"
      end
    end

    env_json = ENV['FIREBASE_SERVICE_ACCOUNT_JSON']
    if env_json.present?
      parsed_env = parse_service_account_json(env_json)
      return { credentials: parsed_env, source: 'FIREBASE_SERVICE_ACCOUNT_JSON' } if parsed_env.present?
      Rails.logger.error 'PushNotificationService: FIREBASE_SERVICE_ACCOUNT_JSON is present but invalid JSON.'
    end

    local_path = Rails.root.join('config', 'firebase-service-account.json')
    if File.exist?(local_path)
      begin
        parsed_local = JSON.parse(File.read(local_path))
        return { credentials: parsed_local, source: 'config/firebase-service-account.json' } if parsed_local.is_a?(Hash)
      rescue => e
        Rails.logger.error "PushNotificationService: Failed to parse local firebase-service-account.json: #{e.message}"
      end
    end

    { credentials: nil, source: 'none' }
  end
end
