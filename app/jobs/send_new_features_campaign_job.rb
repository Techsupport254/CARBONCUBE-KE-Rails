class SendNewFeaturesCampaignJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(seller_id, dry_run = false)
    seller = Seller.find_by(id: seller_id)

    if seller.nil?
      Rails.logger.error "[SendNewFeaturesCampaignJob] Seller #{seller_id} not found"
      return
    end

    if seller.deleted || seller.blocked
      Rails.logger.warn "[SendNewFeaturesCampaignJob] Seller #{seller_id} is deleted or blocked, skipping"
      return
    end

    sent_channels = []

    # Email
    begin
      if dry_run
        Rails.logger.info "[SendNewFeaturesCampaignJob] DRY RUN: would send new_features email to #{seller.email}"
      else
        SellerCommunicationsMailer.with(seller: seller).new_features.deliver_now
        sent_channels << "email"
      end
    rescue => e
      Rails.logger.error "[SendNewFeaturesCampaignJob] Email failed for seller #{seller.id}: #{e.message}"
    end

    # WhatsApp
    if seller.phone_number.present?
      begin
        if dry_run
          Rails.logger.info "[SendNewFeaturesCampaignJob] DRY RUN: would send new_features WhatsApp to #{seller.phone_number}"
        elsif WhatsappMessageLog.already_sent?(seller, 'new_features')
          Rails.logger.info "[SendNewFeaturesCampaignJob] new_features WhatsApp already sent to seller #{seller.id}"
        else
          banner_url = "https://res.cloudinary.com/dwrjceslk/image/upload/c_scale,f_png,q_auto,w_1200/v1/emails/new_features_banner?_a=BACMTiAE"

          components = [
            {
              type: 'header',
              parameters: [
                { type: 'image', image: { link: banner_url } }
              ]
            }
          ]

          result = WhatsAppCloudService.send_template(seller.phone_number, 'new_features', 'en', components)

          if result.is_a?(Hash) && result[:success]
            sent_channels << "whatsapp"
            WhatsappMessageLog.mark_as_sent(
              seller,
              'new_features',
              seller.phone_number,
              result[:message_id]
            )
          else
            error_msg = result.is_a?(Hash) ? result[:error] : 'Unknown error'
            Rails.logger.warn "[SendNewFeaturesCampaignJob] WhatsApp failed for seller #{seller.id}: #{error_msg}"
          end
        end
      rescue => e
        Rails.logger.error "[SendNewFeaturesCampaignJob] WhatsApp exception for seller #{seller.id}: #{e.message}"
      end
    else
      Rails.logger.warn "[SendNewFeaturesCampaignJob] Seller #{seller.id} has no phone number - skipping WhatsApp"
    end

    if sent_channels.any?
      Rails.logger.info "[SendNewFeaturesCampaignJob] new_features campaign sent to seller #{seller.id} via #{sent_channels.join(', ')}"
    else
      Rails.logger.warn "[SendNewFeaturesCampaignJob] No channels sent for seller #{seller.id}"
    end
  end
end
