namespace :email do
  desc "Test general update email with seller 114 only"
  task test_seller_114: :environment do
    puts "Starting email test for seller 114..."
    
    # Find seller 114
    seller = Seller.find_by(id: 114)
    
    if seller.nil?
      puts "Seller with ID 114 not found!"
      exit 1
    end
    
    puts "Found seller: #{seller.fullname} (#{seller.enterprise_name})"
    puts "Email: #{seller.email}"
    puts "Location: #{seller.location}"
    
    # Check if seller has analytics
    puts "Seller Analytics:"
    puts "   - Total Ads: #{seller.ads.count}"
    puts "   - Total Reviews: #{seller.reviews.count}"
    puts "   - Average Rating: #{seller.reviews.average(:rating)&.round(1) || 'N/A'}"
    puts "   - Tier: #{seller.seller_tier&.tier_id || 'Free'}"
    
    # Queue the email job
    puts "\nQueuing email job..."
    
    begin
      # Use deliver_later for background processing
      SellerCommunicationsMailer.general_update(seller).deliver_later
      
      puts "Email job queued successfully!"
      puts "Email will be sent to: #{seller.email}"
      puts "Check your job queue or logs for processing status"
      
    rescue => e
      puts "Error queuing email job: #{e.message}"
      puts "Full error: #{e.backtrace.first(5).join("\n")}"
      exit 1
    end

    puts "\nTest completed successfully!"
    puts "To check job status, run: rails jobs:work"
  end
  
  desc "Send test email immediately (synchronous) for debugging"
  task test_seller_114_now: :environment do
    puts "Starting immediate email test for seller 114..."
    
    seller = Seller.find_by(id: 114)
    
    if seller.nil?
      puts "Seller with ID 114 not found!"
      exit 1
    end
    
    puts "Found seller: #{seller.fullname} (#{seller.enterprise_name})"
    
    begin
      # Send immediately for testing
      SellerCommunicationsMailer.with(seller: seller).general_update.deliver_now
      
      puts "Email sent immediately!"
      puts "Check #{seller.email} for the email"
      
    rescue => e
      puts "Error sending email: #{e.message}"
      puts "Full error: #{e.backtrace.first(5).join("\n")}"
      exit 1
    end

    puts "\nImmediate test completed!"
  end
  
  desc "Preview email template for seller 114"
  task preview_seller_114: :environment do
    puts "Generating email preview for seller 114..."
    
    seller = Seller.find_by(id: 114)
    
    if seller.nil?
      puts "Seller with ID 114 not found!"
      exit 1
    end
    
    puts "Previewing email for: #{seller.fullname} (#{seller.enterprise_name})"
    
    begin
      # Generate the email content
      mail = SellerCommunicationsMailer.with(seller: seller).general_update
      
      puts "\nEmail Details:"
      puts "   Subject: #{mail.subject}"
      puts "   To: #{mail.to}"
      puts "   From: #{mail.from}"
      
      # Save HTML preview to file
      preview_file = Rails.root.join('tmp', 'email_preview_seller_114.html')
      File.write(preview_file, mail.body.raw_source)
      
      puts "\nEmail preview saved to: #{preview_file}"
      puts "Open this file in your browser to preview the email"
      
    rescue => e
      puts "Error generating preview: #{e.message}"
      puts "Full error: #{e.backtrace.first(5).join("\n")}"
      exit 1
    end

    puts "\nPreview generated successfully!"
  end
end
