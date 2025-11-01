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
    
    sent_count = 0
    failed_count = 0
    failed_sellers = []
    
    # Process sellers in batches to avoid memory issues
    active_sellers.find_in_batches(batch_size: 50) do |seller_batch|
      seller_batch.each do |seller|
        begin
          print "📧 Sending to #{seller.fullname} (#{seller.email})... "
          
          # Queue individual email job for each seller
          SendSellerCommunicationJob.perform_later(seller.id, 'black_friday')
          sent_count += 1
          
          puts "✅ Queued"
          
        rescue => e
          failed_count += 1
          failed_sellers << {
            id: seller.id,
            email: seller.email,
            error: e.message
          }
          
          puts "❌ Failed: #{e.message}"
        end
      end
      
      # Small delay between batches to prevent overwhelming the system
      sleep(1) if seller_batch.size == 50
    end
    
    puts ""
    puts "=" * 80
    puts "📊 CAMPAIGN SUMMARY"
    puts "=" * 80
    puts "Total sellers: #{total_sellers}"
    puts "Successfully queued: #{sent_count}"
    puts "Failed to queue: #{failed_count}"
    
    if failed_sellers.any?
      puts ""
      puts "❌ Failed sellers:"
      failed_sellers.each do |failed|
        puts "   - ID: #{failed[:id]}, Email: #{failed[:email]}, Error: #{failed[:error]}"
      end
    end
    
    puts ""
    puts "🎉 Black Friday email campaign completed!"
    puts "💡 Check your job queue or logs for processing status"
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
end

