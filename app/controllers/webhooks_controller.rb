# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET  /api/webhooks/whatsapp — Meta webhook verification
  # POST /api/webhooks/whatsapp — Meta webhook events (messages, status updates, etc.)
  def whatsapp
    if request.get?
      handle_whatsapp_verify
    elsif request.post?
      handle_whatsapp_events
    else
      head :method_not_allowed
    end
  end

  private

  def handle_whatsapp_verify
    mode = params[:'hub.mode']
    challenge = params[:'hub.challenge']
    token = params[:'hub.verify_token'].to_s
    verify_token = ENV.fetch('WHATSAPP_CLOUD_VERIFY_TOKEN', '')

    if mode == 'subscribe' && challenge.present? && token.present? && verify_token.present? &&
       token.bytesize == verify_token.bytesize && ActiveSupport::SecurityUtils.secure_compare(token, verify_token)
      render plain: challenge, content_type: 'text/plain'
    else
      head :forbidden
    end
  end

  def handle_whatsapp_events
    raw_body = request.raw_post.to_s
    signature = request.headers['X-Hub-Signature-256']

    unless verify_signature(raw_body, signature)
      Rails.logger.warn '[Webhooks#whatsapp] Invalid X-Hub-Signature-256'
      head :forbidden
      return
    end

    payload = JSON.parse(raw_body)
    
    # Process the payload via WhatsAppCloudService
    WhatsAppCloudService.handle_webhook_payload(payload)
    
    # Log for debugging
    Rails.logger.info "[Webhooks#whatsapp] Received and processed payload"
    head :ok
  rescue JSON::ParserError => e
    Rails.logger.warn "[Webhooks#whatsapp] Invalid JSON: #{e.message}"
    head :bad_request
  end

  def verify_signature(raw_body, signature_header)
    return false if signature_header.blank? || !signature_header.start_with?('sha256=')

    app_secret = ENV['META_APP_SECRET']
    return false if app_secret.blank?

    expected = signature_header.sub('sha256=', '')
    computed = OpenSSL::HMAC.hexdigest('sha256', app_secret, raw_body)
    expected.bytesize == computed.bytesize && ActiveSupport::SecurityUtils.secure_compare(computed, expected)
  end
end
