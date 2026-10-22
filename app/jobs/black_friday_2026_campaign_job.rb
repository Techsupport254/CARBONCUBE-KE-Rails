# Schedules one SendSellerCommunicationJob per active seller, staggered over a
# send window so Brevo is not hit with a burst. Enqueue with wait_until for the
# campaign date; this job runs once and fans out the per-seller deliveries.
#
#   BlackFriday2026CampaignJob
#     .set(wait_until: Time.utc(2026, 10, 26, 6)) # 9 AM EAT
#     .perform_later
#
class BlackFriday2026CampaignJob < ApplicationJob
  queue_as :broadcast

  EMAIL_TYPE = 'black_friday_2026'.freeze
  CHANNELS = { email: true, whatsapp: false }.freeze
  SEND_WINDOW_MINUTES = (ENV['BLACK_FRIDAY_WINDOW_MINUTES'] || 240).to_i

  def perform
    unless Rails.env.production?
      Rails.logger.info "BlackFriday2026CampaignJob: skipping outside production"
      return
    end

    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where.not(email: [nil, ''])
                    .order(:id)
    total = sellers.count

    if total.zero?
      Rails.logger.info "BlackFriday2026CampaignJob: no active sellers found"
      return
    end

    scheduled = 0
    sellers.find_each do |seller|
      offset = (SEND_WINDOW_MINUTES.to_f * rand).minutes
      SendSellerCommunicationJob
        .set(wait: offset)
        .perform_later(seller.id, EMAIL_TYPE, CHANNELS)
      scheduled += 1
    rescue => e
      Rails.logger.error "BlackFriday2026CampaignJob: failed to schedule seller #{seller.id}: #{e.message}"
    end

    Rails.logger.info "BlackFriday2026CampaignJob: scheduled #{scheduled}/#{total} emails over ~#{SEND_WINDOW_MINUTES}min"
  end
end
