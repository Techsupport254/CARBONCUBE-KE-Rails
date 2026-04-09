class SendSellerMarketingBroadcastJob < ApplicationJob
  queue_as :default

  def perform(template_name = 'seller_onboarding_sw_v1', language_code = 'sw', admin_id = 'fbd79dff-1a39-4150-8fe8-965d11b57c5f')
    Rails.logger.info "=== SELLER MARKETING BROADCAST START ==="
    Rails.logger.info "Template: #{template_name} | Language: #{language_code}"

    # Verify admin exists
    admin = Admin.find_by(id: admin_id)
    unless admin
      Rails.logger.error "❌ Fatal: Admin with ID #{admin_id} not found."
      return { success: false, error: "Admin not found" }
    end

    # Target: All active sellers with a phone number
    # We enqueue each job for parallel processing (Multithreading)
    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where.not(phone_number: [nil, ""])

    total = sellers.count
    Rails.logger.info "Found #{total} sellers to broadcast to. Enqueuing jobs..."

    sent = 0
    failed = 0

    sellers.find_each(batch_size: 50) do |seller|
      # Enqueue the individual job to process in parallel
      SendSingleSellerMarketingJob.perform_later(seller.id, template_name, language_code, admin.id)
      sent += 1
      
      # Tiny sleep between enqueues to prevent database pool exhaustion (50 qps)
      sleep(0.02)
    end

    Rails.logger.info "=== SELLER MARKETING BROADCAST ENQUEUE COMPLETE ==="
    Rails.logger.info "Job queued for #{sent} sellers."
    
    { total_queued: sent }
  end
end
