# frozen_string_literal: true

# Fans a PartnerUpdate out to the partner's network:
#   - subscribed distributors with linked seller accounts get an in-app
#     Notification row plus an FCM push (when they have device tokens)
#   - partner contacts flagged receives_updates get a WhatsApp message
# `pricing` updates only reach notify_pricing distributors; all other kinds
# reach notify_updates subscribers.
class PartnerUpdateFanoutJob < ApplicationJob
  queue_as :low

  def perform(update_id)
    update = PartnerUpdate.find_by(id: update_id)
    return unless update

    partner = update.partner
    recipients =
      if update.pricing?
        partner.distributors.pricing_recipients
      else
        partner.distributors.update_recipients
      end

    recipients.includes(:seller).find_each do |distributor|
      notify_seller(distributor.seller, partner, update)
    rescue StandardError => e
      Rails.logger.error "[PartnerUpdateFanoutJob] distributor #{distributor.id} failed: #{e.message}"
    end

    partner.contacts.update_recipients.find_each do |contact|
      next if contact.phone.blank?

      WhatsAppCloudService.send_template_or_text(
        contact.phone,
        template_name: 'partner_update_v1',
        language: 'en',
        components: update_components(partner, update),
        fallback_text: whatsapp_text(partner, update)
      )
    rescue StandardError => e
      Rails.logger.error "[PartnerUpdateFanoutJob] contact #{contact.id} failed: #{e.message}"
    end
  end

  private

  def notify_seller(seller, partner, update)
    return unless seller

    payload = {
      title: update.title,
      body: update.body.to_s.truncate(140),
      data: {
        'type' => 'partner_update',
        'partner_update_id' => update.id,
        'partner_id' => partner.id,
        'kind' => update.kind,
        'ad_id' => update.ad_id
      }.compact
    }

    Notification.create!(
      recipient: seller,
      notifiable: update,
      title: payload[:title],
      body: payload[:body],
      data: payload[:data]
    )

    tokens = DeviceToken.where(user: seller).pluck(:token)
    PushNotificationService.send_notification(tokens, payload, update) if tokens.any?
  end

  def whatsapp_text(partner, update)
    "#{partner.name} via Carbon Cube: #{update.title}\n#{update.body}"
  end

  # partner_update_v1 body: "Heads up — {{kind}} from {{partner}}:\n\n{{title}}\n{{body}}"
  # Title and body are separate parameters — Meta forbids newlines inside
  # parameter values, so the line break lives in the template text.
  def update_components(partner, update)
    kind_label = update.pricing? ? 'Pricing update' : "#{update.kind.to_s.humanize} update"
    [{
      type: 'body',
      parameters: [
        { type: 'text', text: kind_label },
        { type: 'text', text: partner.name },
        { type: 'text', text: update.title.to_s },
        { type: 'text', text: update.body.to_s }
      ]
    }]
  end
end
