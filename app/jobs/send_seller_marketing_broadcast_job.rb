class SendSellerMarketingBroadcastJob < ApplicationJob
  queue_as :default

  def perform(template_name = 'seller_onboarding_sw_v1', language_code = 'sw', admin_id = 'fbd79dff-1a39-4150-8fe8-965d11b57c5f')
    admin = Admin.find_by(id: admin_id)
    unless admin
      Rails.logger.error "Admin with ID #{admin_id} not found."
      return { success: false, error: "Admin not found" }
    end

    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where.not(phone_number: [nil, ""])

    sent = 0

    sellers.find_each(batch_size: 50) do |seller|
      SendSingleSellerMarketingJob.perform_later(seller.id, template_name, language_code, admin.id)
      sent += 1
      sleep(0.02)
    end

    Rails.logger.info "Seller marketing broadcast complete. Queued #{sent} jobs."
    
    { total_queued: sent }
  end
end
