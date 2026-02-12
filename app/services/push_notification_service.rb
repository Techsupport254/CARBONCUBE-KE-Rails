require 'googleauth'
require 'stringio'

class PushNotificationService
  include HTTParty
  base_uri 'https://fcm.googleapis.com'

  FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'.freeze

  def self.send_notification(tokens, notification_payload, notifiable = nil)
    # tokens: array of strings or a single string
    tokens = Array(tokens)
    return false if tokens.empty?

    project_id = get_project_id
    access_token = get_access_token
    
    unless access_token
      Rails.logger.error "PushNotificationService: Failed to get access token."
      return false
    end

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    success_count = 0
    
    tokens.each do |token|
      body = {
        message: {
          token: token,
          notification: {
            title: notification_payload[:title],
            body: notification_payload[:body]
          },
          data: notification_payload[:data]&.transform_values(&:to_s) || {}
        }
      }

      response = post("/v1/projects/#{project_id}/messages:send", headers: headers, body: body.to_json)
      
      if response&.success?
        success_count += 1
        Rails.logger.info "PushNotificationService: Notification sent to #{token}. Response: #{response.body}"
      else
        Rails.logger.error "PushNotificationService: Failed to send to #{token}. Status: #{response&.code}. Response: #{response&.body}"
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

    success_count > 0
  rescue => e
    Rails.logger.error "PushNotificationService: Exception #{e.message}"
    false
  end

  private

  def self.get_access_token
    json_key = ENV['FIREBASE_SERVICE_ACCOUNT_JSON']
    
    if json_key.present?
      begin
        authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(json_key),
          scope: FCM_SCOPE
        )
        return authorizer.fetch_access_token!['access_token']
      rescue => e
        Rails.logger.error "PushNotificationService: Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON from ENV: #{e.message}"
      end
    end

    # Fallback to file only if ENV is missing or invalid
    key_path = Rails.root.join('config', 'firebase-service-account.json')
    if File.exist?(key_path)
      begin
        authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(key_path),
          scope: FCM_SCOPE
        )
        return authorizer.fetch_access_token!['access_token']
      rescue => e
        Rails.logger.error "PushNotificationService: Failed to get token from file: #{e.message}"
      end
    else
      Rails.logger.error "PushNotificationService: Firebase credentials not found in ENV or at #{key_path}"
    end
    nil
  end

  def self.get_project_id
    json_key = ENV['FIREBASE_SERVICE_ACCOUNT_JSON']
    
    if json_key.present?
      begin
        return JSON.parse(json_key)['project_id']
      rescue => e
        Rails.logger.error "PushNotificationService: Failed to parse project_id from ENV: #{e.message}"
      end
    end

    key_path = Rails.root.join('config', 'firebase-service-account.json')
    if File.exist?(key_path)
      begin
        return JSON.parse(File.read(key_path))['project_id']
      rescue => e
        Rails.logger.error "PushNotificationService: Failed to parse project_id from file: #{e.message}"
      end
    end
    nil
  end
end
