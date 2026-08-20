# frozen_string_literal: true

require 'timeout'

class SendSellerQrJob < ApplicationJob
  queue_as :mailers

  def perform(seller_id, to_email = nil)
    seller = Seller.find_by(id: seller_id)

    if seller.nil?
      Rails.logger.error "SendSellerQrJob: Seller with ID #{seller_id} not found"
      return
    end

    if seller.email.blank? && to_email.blank?
      Rails.logger.warn "SendSellerQrJob: Seller #{seller_id} has no email address"
      return
    end

    begin
      Rails.logger.info "SendSellerQrJob: Generating QR standee and sending email to #{to_email || seller.email}..."
      Timeout.timeout(45) do
        SellerMailer.storefront_qr_welcome(seller, to_email).deliver_now
      end
      Rails.logger.info "SendSellerQrJob: Successfully sent QR standee email to #{to_email || seller.email}"
    rescue => e
      Rails.logger.error "SendSellerQrJob: Failed for seller #{seller_id}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      begin
        Rails.logger.info "SendSellerQrJob: Falling back to welcome email for seller #{seller_id}"
        WelcomeMailer.welcome_email(seller, to_email).deliver_now
      rescue => welcome_error
        Rails.logger.error "SendSellerQrJob: Welcome email fallback also failed for seller #{seller_id}: #{welcome_error.message}"
      end
    end
  end
end
