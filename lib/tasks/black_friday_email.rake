# lib/tasks/black_friday_email.rake
namespace :black_friday do
  desc "Send Black Friday emails to all active sellers"
  task send_to_all: :environment do
    puts "🚀 Starting Black Friday email campaign for all active sellers..."
    
    # Find all active sellers (not deleted, not blocked)
    active_sellers = Seller.where(
      deleted: [false, nil],
      blocked: [false, nil]
    )
    
    total_sellers = active_sellers.count
    
    if total_sellers == 0
      puts "❌ No active sellers found. Campaign cancelled."
      exit 0
    end
    
    puts "📊 Found #{total_sellers} active sellers"
    puts ""
    puts "📋 Sellers list:"
    puts "-" * 80
    
    active_sellers.order(:id).each do |seller|
      name = seller.fullname.to_s[0..30].ljust(32)
      enterprise = seller.enterprise_name.to_s[0..25].ljust(27)
      puts "#{seller.id.to_s.ljust(6)} | #{name} | #{enterprise} | #{seller.email}"
    end
    
    puts "-" * 80
    puts ""
    puts "⚠️  You are about to send Black Friday emails to #{total_sellers} sellers!"
    print "Continue? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'y' || confirmation == 'yes'
      puts "❌ Campaign cancelled by user."
      exit 0
    end
    
    puts ""
    puts "📤 Starting bulk email campaign..."
    puts "   Sidekiq will process jobs in the background"
    puts ""
    
    sent_count = 0
    failed_count = 0
    failed_sellers = []
    start_time = Time.current
    
    # Process sellers in batches to avoid memory issues
    active_sellers.find_in_batches(batch_size: 50) do |seller_batch|
      seller_batch.each_with_index do |seller, index|
        begin
          # Queue individual email job for each seller via Sidekiq
          SendSellerCommunicationJob.perform_later(seller.id, 'black_friday')
          sent_count += 1
          
          # Show progress every 10 sellers to avoid too much output
          if (sent_count + failed_count) % 10 == 0 || sent_count + failed_count == total_sellers
            progress = ((sent_count + failed_count).to_f / total_sellers * 100).round(1)
            puts "   📊 Progress: #{sent_count + failed_count}/#{total_sellers} (#{progress}%) - Queued #{sent_count} emails"
          end
          
        rescue => e
          failed_count += 1
          failed_sellers << {
            id: seller.id,
            email: seller.email,
            error: e.message
          }
          
          puts "   ❌ Failed to queue: #{seller.email} - #{e.message}"
        end
      end
      
      # Small delay between batches to prevent overwhelming Redis
      sleep(0.5) if seller_batch.size == 50
    end
    
    elapsed_time = Time.current - start_time
    
    puts ""
    puts "=" * 80
    puts "📊 CAMPAIGN SUMMARY"
    puts "=" * 80
    puts "Total sellers: #{total_sellers}"
    puts "Successfully queued: #{sent_count}"
    puts "Failed to queue: #{failed_count}"
    puts "Time taken: #{elapsed_time.round(2)} seconds"
    
    if failed_sellers.any?
      puts ""
      puts "❌ Failed sellers:"
      failed_sellers.each do |failed|
        puts "   - ID: #{failed[:id]}, Email: #{failed[:email]}, Error: #{failed[:error]}"
      end
    end
    
    puts ""
    puts "✅ All emails have been queued to Sidekiq"
    puts "📧 Sidekiq will process and send emails in the background"
    puts ""
    puts "💡 Monitor progress:"
    puts "   - Check Sidekiq web UI (if configured)"
    puts "   - View logs: tail -f tmp/sidekiq.log"
    puts "   - Check queue: bundle exec rails runner \"require 'sidekiq/api'; puts Sidekiq::Queue.new('default').size\""
    puts ""
    puts "🎉 Black Friday email campaign queued successfully!"
  end
  
  desc "Send Black Friday email to a specific seller (for testing)"
  task :send_test, [:seller_id] => :environment do |t, args|
    seller_id = args[:seller_id]&.to_i
    
    if seller_id.nil?
      puts "❌ Please provide a seller ID. Usage: rake black_friday:send_test[seller_id]"
      exit 1
    end
    
    puts "🚀 Starting Black Friday email test for seller #{seller_id}..."
    
    seller = Seller.find_by(id: seller_id)
    
    if seller.nil?
      puts "❌ Seller with ID #{seller_id} not found!"
      exit 1
    end
    
    puts "📧 Found seller: #{seller.fullname} (#{seller.enterprise_name})"
    puts "📧 Email: #{seller.email}"
    puts "📧 Location: #{seller.location}"
    puts ""
    puts "📊 Seller Analytics:"
    puts "   - Total Ads: #{seller.ads.where(deleted: false).count}"
    puts "   - Total Reviews: #{seller.reviews.count}"
    puts "   - Average Rating: #{seller.reviews.average(:rating)&.round(1) || 'N/A'}"
    puts "   - Tier: #{seller.tier&.name || 'Free'}"
    puts ""
    print "Send email now? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'y' || confirmation == 'yes'
      puts "❌ Test cancelled by user."
      exit 0
    end
    
    puts ""
    puts "📤 Sending Black Friday email..."
    
    begin
      # Send immediately for testing
      SellerCommunicationsMailer.with(seller: seller).black_friday_email.deliver_now
      
      puts "✅ Black Friday email sent successfully!"
      puts "📧 Check #{seller.email} for the email"
      
    rescue => e
      puts "❌ Error sending email: #{e.message}"
      puts "📋 Full error:"
      puts e.backtrace.first(10).join("\n")
      exit 1
    end
    
    puts ""
    puts "🎉 Test completed successfully!"
  end
  
  desc "Preview Black Friday email template for a specific seller"
  task :preview, [:seller_id] => :environment do |t, args|
    seller_id = args[:seller_id]&.to_i
    
    if seller_id.nil?
      puts "❌ Please provide a seller ID. Usage: rake black_friday:preview[seller_id]"
      exit 1
    end
    
    puts "👀 Generating Black Friday email preview for seller #{seller_id}..."
    
    seller = Seller.find_by(id: seller_id)
    
    if seller.nil?
      puts "❌ Seller with ID #{seller_id} not found!"
      exit 1
    end
    
    puts "📧 Previewing email for: #{seller.fullname} (#{seller.enterprise_name})"
    
    begin
      # Generate the email content
      mail = SellerCommunicationsMailer.with(seller: seller).black_friday_email
      
      puts ""
      puts "📋 Email Details:"
      puts "   Subject: #{mail.subject}"
      puts "   To: #{mail.to}"
      puts "   From: #{mail.from}"
      
      # Save HTML preview to file
      preview_file = Rails.root.join('tmp', 'black_friday_email_preview.html')
      File.write(preview_file, mail.body.raw_source)
      
      puts ""
      puts "✅ Email preview saved to: #{preview_file}"
      puts "🌐 Open this file in your browser to preview the email"
      
    rescue => e
      puts "❌ Error generating preview: #{e.message}"
      puts "📋 Full error:"
      puts e.backtrace.first(10).join("\n")
      exit 1
    end
    
    puts ""
    puts "🎉 Preview generated successfully!"
  end
  
  desc "List all active sellers who would receive Black Friday emails"
  task list_active_sellers: :environment do
    puts "📋 Active Sellers List (for Black Friday campaign)"
    puts "=" * 80
    
    # Find all active sellers (not deleted, not blocked)
    active_sellers = Seller.where(
      deleted: [false, nil],
      blocked: [false, nil]
    ).order(:id)
    
    total_count = active_sellers.count
    
    if total_count == 0
      puts "❌ No active sellers found."
      exit 0
    end
    
    puts ""
    puts "Total Active Sellers: #{total_count}"
    puts ""
    puts "ID     | Name                             | Enterprise                  | Email"
    puts "-" * 80
    
    active_sellers.each do |seller|
      name = seller.fullname.to_s[0..30].ljust(32)
      enterprise = seller.enterprise_name.to_s[0..25].ljust(27)
      puts "#{seller.id.to_s.ljust(6)} | #{name} | #{enterprise} | #{seller.email}"
    end
    
    puts "-" * 80
    puts ""
    puts "✅ Listed #{total_count} active sellers"
  end
  
  desc "SAFE TEST: Send Black Friday email ONLY to victorquaint@gmail.com (admin test)"
  task send_victor_test: :environment do
    puts "🚨 SAFE TEST MODE - ONLY VICTORQUAINT RECIPIENT 🚨"
    puts "=" * 80
    puts "⚠️  This will ONLY send to: victorquaint@gmail.com"
    puts ""
    
    # Find victorquaint by email - STRICT email matching
    seller = Seller.find_by(email: 'victorquaint@gmail.com')
    
    if seller.nil?
      puts "❌ Seller with email 'victorquaint@gmail.com' not found!"
      puts ""
      puts "Available sellers (first 10):"
      Seller.where(deleted: [false, nil]).limit(10).each do |s|
        puts "   - ID: #{s.id}, Email: #{s.email}, Name: #{s.fullname}"
      end
      exit 1
    end
    
    # Double-check email matches exactly
    unless seller.email.downcase.strip == 'victorquaint@gmail.com'
      puts "❌ Email mismatch! Found: #{seller.email}, Expected: victorquaint@gmail.com"
      exit 1
    end
    
    puts "✅ Found seller: #{seller.fullname} (#{seller.enterprise_name})"
    puts "📧 Email: #{seller.email}"
    puts "🆔 ID: #{seller.id}"
    puts ""
    puts "📊 Seller Analytics:"
    puts "   - Total Ads: #{seller.ads.where(deleted: false).count}"
    puts "   - Total Reviews: #{seller.reviews.count}"
    puts "   - Average Rating: #{seller.reviews.average(:rating)&.round(1) || 'N/A'}"
    puts "   - Tier: #{seller.tier&.name || 'Free'}"
    puts ""
    puts "🚨 WARNING: This will send an email to #{seller.email}"
    print "Continue? (yes/no): "
    confirmation = STDIN.gets.chomp.downcase
    
    unless confirmation == 'y' || confirmation == 'yes'
      puts "❌ Test cancelled by user."
      exit 0
    end
    
    puts ""
    puts "📤 Sending Black Friday email..."
    puts "📧 Recipient: #{seller.email} (#{seller.fullname})"
    puts ""
    
    begin
      # Send immediately for testing
      # This will appear as a NEW message (not threaded) due to unique subject and headers
      mail = SellerCommunicationsMailer.with(seller: seller).black_friday_email
      
      puts "📋 Email Details:"
      puts "   Subject: #{mail.subject}"
      puts "   To: #{mail.to.join(', ')}"
      puts "   From: #{mail.from.join(', ')}"
      puts "   Message-ID: #{mail['Message-ID']}"
      puts ""
      
      mail.deliver_now
      
      puts "✅ Black Friday email sent successfully!"
      puts "📧 Check #{seller.email} for the email (should appear as NEW message)"
      
    rescue => e
      puts "❌ Error sending email: #{e.message}"
      puts "📋 Full error:"
      puts e.backtrace.first(10).join("\n")
      exit 1
    end
    
    puts ""
    puts "🎉 Safe test completed successfully!"
    puts "✅ Only victorquaint@gmail.com received the email"
  end
end

