namespace :admin do
  desc "Send WhatsApp product details template to seller (TEST MODE: only optisoftkenya@gmail.com)"
  task send_product_details_whatsapp: :environment do
    # TEST MODE: Only send to optisoftkenya@gmail.com
    seller_email = ENV.fetch('SELLER_EMAIL', 'optisoftkenya@gmail.com')
    
    puts "=== PRODUCT DETAILS WHATSAPP RAKE TASK ==="
    puts "Target Email: #{seller_email}"
    puts "TEST MODE: Only optisoftkenya@gmail.com will receive messages"
    puts "========================================"
    
    if seller_email != 'optisoftkenya@gmail.com'
      puts "WARNING: This is TEST MODE. Only optisoftkenya@gmail.com is allowed."
      puts "Skipping: #{seller_email}"
      exit 0
    end
    
    # Find the seller first to validate
    seller = Seller.find_by(email: seller_email)
    
    if seller.nil?
      puts "ERROR: Seller with email #{seller_email} not found"
      puts "Please check the email address and try again"
      exit 1
    end
    
    puts "Seller found: #{seller.fullname || seller.enterprise_name || 'Unnamed'}"
    puts "Seller Phone: #{seller.phone_number}"
    puts "Sending WhatsApp template and in-app message..."
    
    # Enqueue the job
    job = SendProductDetailsWhatSappJob.perform_later(seller_email)
    
    puts "✅ Job enqueued successfully!"
    puts "Job ID: #{job.job_id}"
    puts "Queue: #{job.queue_name}"
    puts "========================================"
    puts "Check Sidekiq console for job execution details"
  end
  
  desc "Send WhatsApp product details template to all sellers (optimized)"
  task send_product_details_to_all_sellers: :environment do
    puts "=== PRODUCT DETAILS TO ALL SELLERS RAKE TASK ==="
    puts "=============================================="
    
    # Count sellers and check what's already been sent
    all_sellers = Seller.where.not(phone_number: [nil, ''])
    template_name = 'product_details'
    already_sent = WhatsappMessageLog.for_template(template_name).sent_successfully.count
    remaining = all_sellers.count - already_sent
    
    puts "Total sellers with phones: #{all_sellers.count}"
    puts "Already sent: #{already_sent}"
    puts "Remaining to send: #{remaining}"
    
    if remaining == 0
      puts "✅ All sellers have already received the product_details template!"
      puts "No action needed."
      exit 0
    end
    
    puts ""
    puts "⚡ OPTIMIZED VERSION:"
    puts "• Skips sellers who already received the message"
    puts "• Faster processing: 600 messages per minute"
    puts "• Tracks all sends in database"
    puts ""
    puts "⚠️  WARNING: This will send to #{remaining} remaining sellers!"
    puts "⚠️  Press Ctrl+C to cancel, or wait 3 seconds to continue..."
    sleep(3)
    puts ""
    puts "Enqueuing optimized job..."
    
    # Enqueue the optimized job
    job = SendProductDetailsOptimizedJob.perform_later
    
    puts "✅ Optimized job enqueued successfully!"
    puts "Job ID: #{job.job_id}"
    puts "Queue: #{job.queue_name}"
    puts "=============================================="
    puts "Messages will be sent to #{remaining} remaining sellers"
    puts "Estimated time: #{(remaining / 600.0).round(2)} minutes"
    puts "Check Sidekiq console for job execution details"
  end
end
