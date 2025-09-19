#!/usr/bin/env ruby
# Test script for seller 114 email communication
# Usage: ruby lib/scripts/test_seller_114_cli.rb

require_relative '../../config/environment'

class SellerEmailTester
  def initialize
    @seller_id = 114
  end

  def run_test
    puts "🚀 Starting seller email test..."
    puts "=" * 50
    
    find_seller
    display_seller_info
    test_email_generation
    queue_email_job
    send_test_email
    
    puts "\n🎉 Test completed successfully!"
  end

  private

  def find_seller
    @seller = Seller.find_by(id: @seller_id)
    
    if @seller.nil?
      puts "❌ Seller with ID #{@seller_id} not found!"
      puts "\nAvailable sellers (first 5):"
      Seller.limit(5).each do |s|
        puts "  - ID: #{s.id}, Name: #{s.fullname}, Email: #{s.email}"
      end
      exit 1
    end
    
    puts "✅ Found seller: #{@seller.fullname}"
  end

  def display_seller_info
    puts "\n📋 Seller Information:"
    puts "  ID: #{@seller.id}"
    puts "  Name: #{@seller.fullname}"
    puts "  Email: #{@seller.email}"
    puts "  Enterprise: #{@seller.enterprise_name}"
    puts "  Location: #{@seller.location}"
    
    puts "\n📊 Analytics Data:"
    puts "  Total Ads: #{@seller.ads.count}"
    puts "  Total Reviews: #{@seller.reviews.count}"
    puts "  Average Rating: #{@seller.reviews.average(:rating)&.round(1) || 'N/A'}"
    puts "  Tier: #{@seller.seller_tier&.tier_id || 'Free'}"
  end

  def test_email_generation
    puts "\n📤 Testing email generation..."
    
    begin
      @mail = SellerCommunicationsMailer.general_update(@seller)
      
      puts "✅ Email generated successfully!"
      puts "  Subject: #{@mail.subject}"
      puts "  To: #{@mail.to}"
      puts "  From: #{@mail.from}"
      
      # Save preview
      save_email_preview
      
    rescue => e
      puts "❌ Error generating email: #{e.message}"
      puts "📋 Backtrace:"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  def save_email_preview
    preview_file = Rails.root.join('tmp', 'email_preview_seller_114.html')
    File.write(preview_file, @mail.body.raw_source)
    puts "📄 Email preview saved to: #{preview_file}"
  end

  def queue_email_job
    puts "\n🔄 Queuing email job..."
    
    begin
      SendSellerCommunicationJob.perform_later(@seller.id, 'general_update')
      puts "✅ Email job queued successfully!"
      puts "💡 To process jobs, run: rails jobs:work"
      
    rescue => e
      puts "❌ Error queuing job: #{e.message}"
    end
  end

  def send_test_email
    puts "\n📤 Sending test email immediately..."
    
    begin
      @mail.deliver_now
      puts "✅ Email sent immediately!"
      puts "📧 Check #{@seller.email} for the email"
      
    rescue => e
      puts "❌ Error sending email: #{e.message}"
      puts "📋 Backtrace:"
      puts e.backtrace.first(5).join("\n")
    end
  end
end

# Run the test
if __FILE__ == $0
  tester = SellerEmailTester.new
  tester.run_test
end
