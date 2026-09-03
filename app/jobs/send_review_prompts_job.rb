# frozen_string_literal: true

class SendReviewPromptsJob < ApplicationJob
  queue_as :low

  BATCH_SIZE = 100
  FIRST_DELAY = 24.hours
  REMINDER_DELAYS = [3.days, 7.days].freeze
  QUALIFYING_EVENTS = %w[Reveal-Seller-Details Message-Seller].freeze

  def perform
    create_prompts
    send_ready_prompts
  end

  private

  def create_prompts
    qualifying_events.find_each do |event|
      next unless event.buyer&.email.present?
      next unless event.ad && !event.ad.deleted?
      next if ReviewPrompt.exists?(buyer_id: event.buyer_id, ad_id: event.ad_id)
      next if Review.exists?(buyer_id: event.buyer_id, ad_id: event.ad_id)

      ReviewPrompt.create!(
        buyer: event.buyer,
        ad: event.ad,
        click_event: event,
        status: 'pending',
        channel: 'email',
        scheduled_at: event.created_at + FIRST_DELAY
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Review prompt skipped for event #{event.id}: #{e.message}")
    end
  end

  def send_ready_prompts
    ReviewPrompt.ready.limit(BATCH_SIZE).find_each do |prompt|
      next unless prompt.buyer&.email.present?
      next if prompt.ad&.deleted?

      MarketingMailer
        .product_review_request(
          name: prompt.buyer.fullname,
          email: prompt.buyer.email,
          products: [product_payload(prompt)]
        )
        .deliver_later

      prompt.mark_sent!(next_scheduled_at: next_scheduled_at_for(prompt))
    rescue StandardError => e
      Rails.logger.error("Failed to send review prompt #{prompt.id}: #{e.message}")
    end
  end

  def qualifying_events
    ClickEvent
      .where(event_type: QUALIFYING_EVENTS)
      .where.not(buyer_id: nil)
      .where.not(id: ReviewPrompt.where.not(click_event_id: nil).select(:click_event_id))
      .where('created_at >= ?', 30.days.ago)
      .includes(:buyer, :ad)
  end

  def product_payload(prompt)
    ad = prompt.ad
    {
      id: ad.id,
      title: ad.title,
      seller_name: ad.seller&.enterprise_name || ad.seller&.fullname || 'a Carbon Cube Kenya seller',
      image_url: ad.media&.first || 'https://carboncube-ke.com/logo.png',
      review_url: MarketingMailer.review_url_for(ad)
    }
  end

  def next_scheduled_at_for(prompt)
    new_count = prompt.reminders_count + 1
    return nil if new_count >= ReviewPrompt::MAX_SENDS

    Time.current + REMINDER_DELAYS[new_count - 1]
  end
end
