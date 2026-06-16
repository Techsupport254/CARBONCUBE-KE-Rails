namespace :admin do
  desc "Send WhatsApp listing update template to all sellers (optimized)"
  task send_listing_update_to_all_sellers: :environment do
    puts "=== LISTING UPDATE TO ALL SELLERS RAKE TASK ==="
    puts "=============================================="
    
    # Count active sellers and check what's already been sent
    all_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil]).where.not(phone_number: [nil, ''])
    template_name = 'seller_listing_update'
    already_sent = WhatsappMessageLog.for_template(template_name).sent_successfully.count
    remaining = all_sellers.count - already_sent
    
    puts "Total active sellers with phones: #{all_sellers.count}"
    puts "Already sent: #{already_sent}"
    puts "Remaining to send: #{remaining}"
    
    if remaining <= 0
      puts "✅ All active sellers have already received the #{template_name} template!"
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
    job = SendListingUpdateOptimizedJob.perform_later
    
    puts "✅ Optimized job enqueued successfully!"
    puts "Job ID: #{job.job_id}"
    puts "Queue: #{job.queue_name}"
    puts "=============================================="
    puts "Messages will be sent to #{remaining} remaining sellers"
    puts "Estimated time: #{(remaining / 600.0).round(2)} minutes"
    puts "Check Sidekiq console for job execution details"
  end
end
