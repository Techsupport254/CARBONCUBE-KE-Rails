class SellerVerificationNotificationJob < ApplicationJob
  queue_as :default

  # Notifies the seller (push + email + WhatsApp) that the field team verified
  # their shop, listing any details that were corrected.
  def perform(verification_id)
    verification = SellerVerification.includes(:seller).find_by(id: verification_id)
    return unless verification&.seller
    return unless verification.successful?

    seller = verification.seller

    title = verification.corrected? ? 'Your shop details were updated' : 'Your shop was verified'

    send_push(seller, title, push_body(verification), verification)
    send_email(seller, verification)
    send_whatsapp(seller, whatsapp_body(verification))
  rescue => e
    Rails.logger.error "SellerVerificationNotificationJob failed for #{verification_id}: #{e.message}"
    raise
  end

  private

  # Short, no-markdown line for push notifications.
  def push_body(verification)
    if verification.corrected?
      labels = verification.corrected_fields.map { |f| SellerVerification.field_label(f) }
      "Our field team verified your shop and updated: #{labels.join(', ')}."
    else
      'Our field team verified your shop — all your details were confirmed correct.'
    end
  end

  # WhatsApp markdown body. When corrected, each change is listed as
  # "*Field*: old → new"; when clean, the seller is told everything checked
  # out. Newlines get squished inside template params, so bullets keep it
  # readable in both forms.
  def whatsapp_body(verification)
    if verification.corrected?
      lines = verification.corrected_fields.map do |field|
        diff = verification.corrections[field] || {}
        old = diff['old'].presence || '—'
        new = diff['new'].presence || '—'
        "• *#{SellerVerification.field_label(field)}*: #{old} → #{new}"
      end
      "Our field team verified your shop and updated these details:\n\n#{lines.join("\n")}"
    else
      'Our field team verified your shop and confirmed all your details are correct — ' \
        'business name, phone number and location are all up to date. No changes were needed.'
    end
  end

  def send_push(seller, title, body, verification)
    tokens = seller.device_tokens.pluck(:token)
    return if tokens.empty?

    PushNotificationService.send_notification_with_details(
      tokens,
      {
        title: title,
        body: body,
        data: { type: 'seller_verification', verification_id: verification.id }
      }
    )
  rescue => e
    Rails.logger.error "SellerVerificationNotificationJob push failed: #{e.message}"
  end

  def send_email(seller, verification)
    return if seller.email.blank?

    SellerMailer.field_verification_notice(seller, verification).deliver_now
  rescue => e
    Rails.logger.error "SellerVerificationNotificationJob email failed: #{e.message}"
  end

  def send_whatsapp(seller, body)
    return if seller.phone_number.blank?

    seller_name = seller.enterprise_name.presence || seller.fullname.presence || 'Seller'

    WhatsAppCloudService.send_template_or_text(
      seller.phone_number,
      template_name: 'seller_field_verification',
      components: [
        {
          type: 'body',
          parameters: [
            { type: 'text', text: seller_name },
            { type: 'text', text: body }
          ]
        }
      ],
      fallback_text: "Hello #{seller_name},\n\n#{body}\n\nIf anything looks wrong, reply to this message and our team will help.\n\n*Carbon Cube Kenya*"
    )
  rescue => e
    Rails.logger.error "SellerVerificationNotificationJob whatsapp failed: #{e.message}"
  end
end
