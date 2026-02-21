namespace :seller_performance do
  desc "Send Performance Update email to ALL active sellers systematically"
  task send_bulk: :environment do
    puts "🔍 Fetching active sellers for systematic performance update..."
    
    # Target: Active sellers (not blocked, not deleted)
    # We prioritize those with ads first as they have the most data
    sellers = Seller.active.order(ads_count: :desc)
    total = sellers.count
    
    puts "✅ Found #{total} active sellers."
    
    unless ENV['CONFIRM'] == 'true'
      puts "⚠️  Throttling: 1 email every 2 seconds to ensure high inboxing rates."
      puts "⚠️  Unique subjects and Message-IDs will be generated per seller."
      print "❓ Proceed with sending to #{total} sellers? (type 'yes' to confirm): "
      STDOUT.flush
      input = STDIN.gets.chomp.downcase
      
      unless input == 'yes'
        puts "🛑 Aborted."
        exit
      end
    end
    
    puts "🚀 Launching systematic send (Throttled at 2.0s)..."
    
    success = 0
    failed = 0
    
    sellers.find_each.with_index do |seller, index|
      begin
        # Use .with(seller: seller) as the mailer uses params[:seller]
        SellerCommunicationsMailer.with(seller: seller).seller_growth_initiative.deliver_now
        success += 1
        puts "[#{index + 1}/#{total}] ✅ Sent to #{seller.email} (#{seller.enterprise_name})"
      rescue => e
        failed += 1
        puts "[#{index + 1}/#{total}] ❌ Failed for #{seller.email}: #{e.message}"
      end
      
      # Throttling to bypass bulk filters and stay in the Primary tab
      # 2 seconds = 30 emails per minute. Safe for Brevo/SMTP limits.
      sleep 2.0 if index < total - 1
    end
    
    puts "\n🏁 Performance Update complete!"
    puts "📊 Summary: #{success} sent, #{failed} failed, #{total} total."
  end

  desc "Send Performance Update to a specific seller (test)"
  task :test_send, [:email] => :environment do |t, args|
    email = args[:email] || 'victorquaint@gmail.com'
    seller = Seller.find_by(email: email)
    
    unless seller
      puts "❌ Seller not found: #{email}"
      exit
    end
    
    puts "🚀 Sending individual Performance Update to #{seller.fullname} (#{seller.email})..."
    SellerCommunicationsMailer.with(seller: seller).seller_growth_initiative.deliver_now
    puts "✅ Sent!"
  end
end
