#!/usr/bin/env ruby
# Comprehensive email testing script with detailed logging
# Usage: ruby lib/scripts/debug_email_delivery.rb

require_relative '../../config/environment'

class EmailDeliveryDebugger
  def initialize
    @seller_id = 114
  end

  def run_debug
    puts "🔍 === EMAIL DELIVERY DEBUG SESSION ==="
    puts "Time: #{Time.current}"
    puts "Rails Environment: #{Rails.env}"
    puts "=" * 50
    
    check_environment_variables
    check_smtp_configuration
    check_seller_data
    test_email_generation
    test_email_delivery
    test_job_processing
    
    puts "\n🎯 === DEBUG SESSION COMPLETE ==="
  end

  private

  def check_environment_variables
    puts "\n📋 ENVIRONMENT VARIABLES CHECK:"
    puts "BREVO_SMTP_USER: #{ENV['BREVO_SMTP_USER'] ? 'SET ✅' : 'NOT SET ❌'}"
    puts "BREVO_SMTP_PASSWORD: #{ENV['BREVO_SMTP_PASSWORD'] ? 'SET ✅' : 'NOT SET ❌'}"
    puts "BREVO_EMAIL: #{ENV['BREVO_EMAIL'] || 'NOT SET ❌'}"
    puts "RAILS_ENV: #{ENV['RAILS_ENV'] || 'NOT SET ❌'}"
  end

  def check_smtp_configuration
    puts "\n📧 SMTP CONFIGURATION CHECK:"
    puts "Delivery Method: #{ActionMailer::Base.delivery_method}"
    puts "SMTP Address: #{ActionMailer::Base.smtp_settings[:address]}"
    puts "SMTP Port: #{ActionMailer::Base.smtp_settings[:port]}"
    puts "SMTP Domain: #{ActionMailer::Base.smtp_settings[:domain]}"
    puts "SMTP Authentication: #{ActionMailer::Base.smtp_settings[:authentication]}"
    puts "SMTP StartTLS: #{ActionMailer::Base.smtp_settings[:enable_starttls_auto]}"
    puts "SMTP Username: #{ActionMailer::Base.smtp_settings[:user_name] ? 'SET ✅' : 'NOT SET ❌'}"
    puts "SMTP Password: #{ActionMailer::Base.smtp_settings[:password] ? 'SET ✅' : 'NOT SET ❌'}"
    puts "Raise Delivery Errors: #{ActionMailer::Base.raise_delivery_errors}"
    puts "Perform Deliveries: #{ActionMailer::Base.perform_deliveries}"
  end

  def check_seller_data
    puts "\n👤 SELLER DATA CHECK:"
    seller = Seller.find_by(id: @seller_id)
    
    if seller.nil?
      puts "❌ Seller with ID #{@seller_id} not found!"
      return false
    end
    
    puts "✅ Seller found: #{seller.fullname}"
    puts "Email: #{seller.email}"
    puts "Enterprise: #{seller.enterprise_name}"
    puts "Location: #{seller.location}"
    puts "Total Ads: #{seller.ads.count}"
    puts "Total Reviews: #{seller.reviews.count}"
    puts "Average Rating: #{seller.reviews.average(:rating)&.round(1) || 'N/A'}"
    puts "Tier: #{seller.seller_tier&.tier_id || 'Free'}"
    
    true
  end

  def test_email_generation
    puts "\n📝 EMAIL GENERATION TEST:"
    
    begin
      seller = Seller.find(@seller_id)
      mail = SellerCommunicationsMailer.general_update(seller)
      
      puts "✅ Email generated successfully"
      puts "From: #{mail.from}"
      puts "To: #{mail.to}"
      puts "Subject: #{mail.subject}"
      puts "Body Length: #{mail.body.raw_source.length} characters"
      
      # Save email content for inspection
      preview_file = Rails.root.join('tmp', 'debug_email_content.html')
      File.write(preview_file, mail.body.raw_source)
      puts "📄 Email content saved to: #{preview_file}"
      
    rescue => e
      puts "❌ Email generation failed: #{e.message}"
      puts "Error Class: #{e.class}"
      puts "Backtrace:"
      e.backtrace.first(5).each { |line| puts "  #{line}" }
    end
  end

  def test_email_delivery
    puts "\n📤 EMAIL DELIVERY TEST:"
    
    begin
      seller = Seller.find(@seller_id)
      
      puts "Attempting to send email..."
      Rails.logger.info "=== MANUAL EMAIL DELIVERY TEST START ==="
      
      mail = SellerCommunicationsMailer.general_update(seller)
      mail.deliver_now
      
      puts "✅ Email sent successfully!"
      puts "📧 Check #{seller.email} for the email"
      
      Rails.logger.info "=== MANUAL EMAIL DELIVERY TEST SUCCESS ==="
      
    rescue => e
      puts "❌ Email delivery failed: #{e.message}"
      puts "Error Class: #{e.class}"
      puts "Backtrace:"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
      
      Rails.logger.error "=== MANUAL EMAIL DELIVERY TEST FAILED ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Class: #{e.class}"
    end
  end

  def test_job_processing
    puts "\n⚙️ JOB PROCESSING TEST:"
    
    begin
      puts "Testing job processing..."
      Rails.logger.info "=== JOB PROCESSING TEST START ==="
      
      SendSellerCommunicationJob.perform_now(@seller_id, 'general_update')
      
      puts "✅ Job processed successfully!"
      
      Rails.logger.info "=== JOB PROCESSING TEST SUCCESS ==="
      
    rescue => e
      puts "❌ Job processing failed: #{e.message}"
      puts "Error Class: #{e.class}"
      puts "Backtrace:"
      e.backtrace.first(10).each { |line| puts "  #{line}" }
      
      Rails.logger.error "=== JOB PROCESSING TEST FAILED ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Class: #{e.class}"
    end
  end
end

# Run the debugger
if __FILE__ == $0
  debugger = EmailDeliveryDebugger.new
  debugger.run_debug
end
