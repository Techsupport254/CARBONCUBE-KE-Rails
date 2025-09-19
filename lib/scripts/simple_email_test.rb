#!/usr/bin/env ruby
# Simple Email Deliverability Test Script
# Usage: rails runner lib/scripts/simple_email_test.rb

class SimpleEmailDeliverabilityTest
  def initialize
    @test_email = 'victorquaint@gmail.com' # Seller 114's email
  end

  def run_tests
    puts "🔍 Email Deliverability Test"
    puts "=" * 40
    
    test_email_generation
    test_email_headers
    test_email_content
    send_test_email
    
    puts "\n🎉 Tests completed!"
    puts "\n💡 Common reasons emails don't appear in inbox:"
    puts "   1. Missing SPF/DKIM/DMARC records"
    puts "   2. Sender reputation issues"
    puts "   3. Content filtering"
    puts "   4. Email client settings"
    puts "\n🔧 Recommended fixes:"
    puts "   1. Add SPF record: v=spf1 include:spf.brevo.com ~all"
    puts "   2. Enable DKIM in Brevo dashboard"
    puts "   3. Add DMARC record: v=DMARC1; p=quarantine; rua=mailto:dmarc@carboncube-ke.com"
    puts "   4. Check Brevo sender reputation"
  end

  private

  def test_email_generation
    puts "\n📧 Testing Email Generation..."
    
    begin
      seller = Seller.find(114)
      @mail = SellerCommunicationsMailer.with(seller: seller).general_update
      
      puts "✅ Email generated successfully"
      puts "   Subject: #{@mail.subject}"
      puts "   From: #{@mail.from}"
      puts "   To: #{@mail.to}"
      
    rescue => e
      puts "❌ Email generation failed: #{e.message}"
    end
  end

  def test_email_headers
    puts "\n📋 Testing Email Headers..."
    
    return unless @mail
    
    important_headers = [
      'Message-ID', 'Return-Path', 'Organization', 
      'X-Mailer', 'List-Unsubscribe', 'Reply-To'
    ]
    
    important_headers.each do |header|
      if @mail[header]
        puts "✅ #{header}: #{@mail[header]}"
      else
        puts "⚠️  #{header}: Missing"
      end
    end
    
    # Check for proper Message-ID format
    message_id = @mail['Message-ID'].to_s
    if message_id.include?('@carboncube-ke.com')
      puts "✅ Message-ID has proper domain"
    else
      puts "❌ Message-ID missing or wrong domain"
    end
  end

  def test_email_content
    puts "\n📝 Testing Email Content..."
    
    return unless @mail
    
    body = @mail.body.raw_source
    
    # Check content length
    puts "   Content length: #{body.length} characters"
    
    if body.length > 1000
      puts "✅ Content length is adequate"
    else
      puts "⚠️  Content might be too short"
    end
    
    # Check for proper HTML structure
    if body.include?('<!DOCTYPE html>') && body.include?('</html>')
      puts "✅ Proper HTML structure"
    else
      puts "❌ Missing HTML structure"
    end
    
    # Check for inline styles
    if body.include?('style=') && !body.include?('<style>')
      puts "✅ Using inline styles (good for email clients)"
    else
      puts "⚠️  Not using inline styles"
    end
    
    # Check for spam triggers
    spam_words = ['FREE', 'WIN', 'URGENT', 'ACT NOW', 'CLICK HERE', '$$$']
    found_spam = spam_words.select { |word| body.upcase.include?(word) }
    
    if found_spam.empty?
      puts "✅ No obvious spam triggers"
    else
      puts "⚠️  Potential spam triggers: #{found_spam.join(', ')}"
    end
  end

  def send_test_email
    puts "\n📤 Sending Test Email..."
    
    return unless @mail
    
    begin
      # Add test headers
      @mail['X-Test-Email'] = 'true'
      @mail['X-Test-Timestamp'] = Time.current.iso8601
      @mail['X-Test-Purpose'] = 'Deliverability Test'
      
      @mail.deliver_now
      
      puts "✅ Test email sent successfully!"
      puts "   To: #{@mail.to}"
      puts "   Message-ID: #{@mail['Message-ID']}"
      puts "   Check #{@test_email} for the email"
      
    rescue => e
      puts "❌ Test email failed: #{e.message}"
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = SimpleEmailDeliverabilityTest.new
  tester.run_tests
end
