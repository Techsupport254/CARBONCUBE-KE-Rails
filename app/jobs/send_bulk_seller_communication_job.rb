class SendBulkSellerCommunicationJob < ApplicationJob
  queue_as :default

  def perform(email_type = 'general_update', auto_confirm = false)
    # Log to both Rails logger and Sidekiq logger for visibility
    log_message = "=== BULK SELLER COMMUNICATION JOB START ==="
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Job ID: #{job_id} | Email Type: #{email_type}"
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Job Queue: #{queue_name} | Priority: #{priority}"
    Rails.logger.info log_message
    puts log_message
    
    # Find all active sellers (not deleted, not blocked)
    active_sellers = Seller.where(
      deleted: [false, nil],
      blocked: [false, nil]
    )
    
    total_sellers = active_sellers.count
    log_message = "Found #{total_sellers} active sellers to send emails to"
    Rails.logger.info log_message
    puts log_message
    
    if total_sellers == 0
      log_message = "No active sellers found. Job completed."
      Rails.logger.info log_message
      puts log_message
      return
    end

    # Show the list of sellers
    puts "\n" + "="*80
    puts "SELLERS LIST - PRODUCTION DATABASE"
    puts "="*80
    puts "ID\tName\t\t\t\tEmail"
    puts "-"*80
    
    active_sellers.order(:id).each do |seller|
      name = seller.fullname.to_s[0..30].ljust(30) # Truncate and pad name
      puts "#{seller.id}\t#{name}\t#{seller.email}"
    end
    
    puts "-"*80
    puts "TOTAL: #{total_sellers} active sellers"
    puts "="*80
    
    # Ask for confirmation unless auto_confirm is true
    unless auto_confirm
      puts "\nDo you want to proceed with sending emails to these #{total_sellers} sellers? (y/n): "
      confirmation = STDIN.gets.chomp.downcase
      
      unless confirmation == 'y' || confirmation == 'yes'
        puts "Operation cancelled by user."
        return { status: 'cancelled', message: 'User cancelled the operation' }
      end
    end
    
    puts "\nProceeding with email sending..."
    
    sent_count = 0
    failed_count = 0
    failed_sellers = []
    
    # Process sellers in batches to avoid memory issues
    active_sellers.find_in_batches(batch_size: 50) do |seller_batch|
      seller_batch.each do |seller|
        begin
          log_message = "Processing seller: #{seller.id} | #{seller.fullname} | #{seller.email}"
          Rails.logger.info log_message
          puts log_message
          
          # Queue individual email job for each seller
          SendSellerCommunicationJob.perform_later(seller.id, email_type)
          sent_count += 1
          
          log_message = "✅ Queued email for seller #{seller.id} (#{seller.email})"
          Rails.logger.info log_message
          puts log_message
          
        rescue => e
          failed_count += 1
          failed_sellers << {
            id: seller.id,
            email: seller.email,
            error: e.message
          }
          
          log_message = "❌ Failed to queue email for seller #{seller.id}: #{e.message}"
          Rails.logger.error log_message
          puts log_message
        end
      end
      
      # Small delay between batches to prevent overwhelming the system
      sleep(1) if seller_batch.size == 50
    end
    
    # Log final results
    log_message = "=== BULK EMAIL JOB COMPLETED ==="
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Total sellers processed: #{total_sellers}"
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Successfully queued emails: #{sent_count}"
    Rails.logger.info log_message
    puts log_message
    
    log_message = "Failed to queue emails: #{failed_count}"
    Rails.logger.info log_message
    puts log_message
    
    if failed_sellers.any?
      log_message = "Failed sellers:"
      Rails.logger.error log_message
      puts log_message
      
      failed_sellers.each do |failed_seller|
        log_message = "  - ID: #{failed_seller[:id]}, Email: #{failed_seller[:email]}, Error: #{failed_seller[:error]}"
        Rails.logger.error log_message
        puts log_message
      end
    end
    
    log_message = "=== BULK SELLER COMMUNICATION JOB END ==="
    Rails.logger.info log_message
    puts log_message
    
    # Return summary for monitoring
    {
      status: 'completed',
      total_sellers: total_sellers,
      queued_emails: sent_count,
      failed_emails: failed_count,
      failed_sellers: failed_sellers
    }
  end
end
