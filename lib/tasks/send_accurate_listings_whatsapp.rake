namespace :admin do
  desc "Send WhatsApp accurate listings template to seller (TEST MODE: only kiruivictor097@gmail.com)"
  task send_accurate_listings_whatsapp: :environment do
    seller_email = ENV.fetch('SELLER_EMAIL', 'kiruivictor097@gmail.com')
    
    puts "=== ACCURATE LISTINGS WHATSAPP RAKE TASK ==="
    puts "Target Email: #{seller_email}"
    puts "TEST MODE: Only kiruivictor097@gmail.com will receive messages"
    puts "============================================="
    
    if seller_email != 'kiruivictor097@gmail.com'
      puts "WARNING: This is TEST MODE. Only kiruivictor097@gmail.com is allowed."
      puts "Skipping: #{seller_email}"
      exit 0
    end
    
    # Find the seller first to validate
    seller = Seller.find_by(email: seller_email)
    
    if seller.nil?
      puts "ERROR: Seller with email #{seller_email} not found"
      puts "Please check the email address or register this seller first"
      exit 1
    end
    
    puts "Seller found: #{seller.fullname || seller.enterprise_name || 'Unnamed'}"
    puts "Seller Phone: #{seller.phone_number}"
    puts "Sending WhatsApp template and in-app message..."
    
    # Enqueue the job
    job = SendAccurateListingsWhatsappJob.perform_later(seller_email)
    
    puts "✅ Job enqueued successfully!"
    puts "Job ID: #{job.job_id}"
    puts "Queue: #{job.queue_name}"
    puts "============================================="
    puts "Check Sidekiq console for job execution details"
  end
  
  desc "Send WhatsApp accurate listings template to all sellers (optimized with dry_run support)"
  task :send_accurate_listings_to_all_sellers, [:dry_run] => :environment do |t, args|
    dry_run_input = args[:dry_run] || ENV['DRY_RUN']
    dry_run = dry_run_input != 'false'

    puts "=== ACCURATE LISTINGS TO ALL SELLERS RAKE TASK ==="
    puts "Dry Run Mode: #{dry_run}"
    puts "=================================================="
    
    # Count sellers and check what's already been sent
    all_sellers = Seller.where(deleted: [false, nil], blocked: [false, nil]).where.not(phone_number: [nil, ''])
    template_name = 'accurate_listings'
    already_sent = WhatsappMessageLog.for_template(template_name).sent_successfully.count
    remaining = all_sellers.count - already_sent
    
    puts "Total active sellers with phones: #{all_sellers.count}"
    puts "Already sent: #{already_sent}"
    puts "Remaining to process: #{remaining}"
    
    if remaining == 0
      puts "✅ All sellers have already received the accurate_listings template!"
      puts "No action needed."
      exit 0
    end
    
    puts ""
    if dry_run
      puts "⚡ DRY RUN ACTIVE:"
      puts "• No WhatsApp messages will actually be sent."
      puts "• No database log updates will be written."
      puts "• Logs will print exactly which sellers would be processed."
    else
      puts "⚡ LIVE PRODUCTION RUN ACTIVE:"
      puts "• WhatsApp template messages will be sent to #{remaining} sellers."
      puts "• Spaced out processing to prevent Meta rate limits."
      puts "• Sends will be recorded in the database."
    end
    puts ""
    puts "⚠️  Press Ctrl+C to cancel, or wait 3 seconds to continue..."
    sleep(3)
    puts ""
    puts "Enqueuing optimized job (dry_run: #{dry_run})..."
    
    # Enqueue the optimized job
    job = SendAccurateListingsOptimizedJob.perform_later(dry_run)
    
    puts "✅ Optimized job enqueued successfully!"
    puts "Job ID: #{job.job_id}"
    puts "Queue: #{job.queue_name}"
    puts "=================================================="
    if dry_run
      puts "Run with dry_run=false to execute a live production blast:"
      puts "  bundle exec rails admin:send_accurate_listings_to_all_sellers[false]"
    else
      puts "Estimated execution time: #{(remaining / 600.0).round(2)} minutes"
    end
    puts "Check Sidekiq console for job execution details"
  end
end
