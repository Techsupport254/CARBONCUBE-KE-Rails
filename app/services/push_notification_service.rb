class PushNotificationService
  include HTTParty
  base_uri 'https://fcm.googleapis.com/fcm'

  def self.send_notification(tokens, notification_payload)
    # tokens: array of strings
    
    # We try to use the key from environment
    server_key = ENV['FCM_SERVER_KEY']
    
    unless server_key
      Rails.logger.warn "PushNotificationService: FCM_SERVER_KEY not set. Skipping notification."
      return false
    end

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "key=#{server_key}"
    }

    body = {
      registration_ids: tokens,
      notification: {
        title: notification_payload[:title],
        body: notification_payload[:body],
        sound: 'default'
      },
      data: notification_payload[:data],
      priority: 'high'
    }

    response = post('/send', headers: headers, body: body.to_json)
    
    if response.success?
      Rails.logger.info "PushNotificationService: Notification sent successfully. Response: #{response.body}"
      
      # Persist the notification in the database for history
      # We need to find the recipient user object from the token to link it
      # This is inefficient if sending to multiple tokens for different users, 
      # but typically 'tokens' array here belongs to the SAME user or we loop.
      # Current structure of calls: 
      # Message.rb: tokens = DeviceToken.where(user: recipient) -> All tokens belong to ONE recipient.
      
      # We can infer the recipient from the first token
      first_token = tokens.first
      device_token = DeviceToken.find_by(token: first_token)
      
      if device_token&.user
        Notification.create(
          recipient: device_token.user,
          title: notification_payload[:title],
          body: notification_payload[:body],
          data: notification_payload[:data],
          # If data has an ID and Type, we could link notifiable, but let's stick to simple data dump for now
          # OR if the caller passed 'notifiable' in the payload (which they don't currently), we could use it.
          # For now, data is enough.
          status: 'sent'
        )
      end

      true
    else
      Rails.logger.error "PushNotificationService: Failed to send notification. Response: #{response.body}"
      false
    end
  rescue => e
    Rails.logger.error "PushNotificationService: Exception #{e.message}"
    false
  end
end
