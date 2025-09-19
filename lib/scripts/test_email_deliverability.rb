#!/usr/bin/env ruby
# Email Deliverability Test Script
# Usage: rails runner lib/scripts/test_email_deliverability.rb

require 'net/smtp'
require 'net/dns'

class EmailDeliverabilityTester
  def initialize
    @domain = 'carboncube-ke.com'
    @smtp_host = 'smtp-relay.brevo.com'
    @smtp_port = 587
    @from_email = ENV['BREVO_EMAIL']
    @test_email = 'victorquaint@gmail.com' # Seller 114's email
  end

  def run_all_tests
    puts "🔍 Email Deliverability Test Suite"
    puts "=" * 50
    
    test_dns_records
    test_smtp_connection
    test_email_headers
    test_email_content
    send_test_email
    
    puts "\n🎉 All tests completed!"
  end

  private

  def test_dns_records
    puts "\n📡 Testing DNS Records..."
    
    # Test SPF record
    spf_record = get_dns_record(@domain, 'TXT')
    spf_found = spf_record&.any? { |record| record.include?('v=spf1') }
    
    if spf_found
      puts "✅ SPF record found"
      spf_record.each { |record| puts "   #{record}" if record.include?('v=spf1') }
    else
      puts "❌ SPF record not found - This can cause deliverability issues"
      puts "   Add this SPF record to your DNS:"
      puts "   v=spf1 include:spf.brevo.com ~all"
    end
    
    # Test DMARC record
    dmarc_record = get_dns_record("_dmarc.#{@domain}", 'TXT')
    dmarc_found = dmarc_record&.any? { |record| record.include?('v=DMARC1') }
    
    if dmarc_found
      puts "✅ DMARC record found"
      dmarc_record.each { |record| puts "   #{record}" if record.include?('v=DMARC1') }
    else
      puts "⚠️  DMARC record not found - Consider adding one"
      puts "   Add this DMARC record to your DNS:"
      puts "   v=DMARC1; p=quarantine; rua=mailto:dmarc@#{@domain}"
    end
    
    # Test MX record
    mx_record = get_dns_record(@domain, 'MX')
    if mx_record && !mx_record.empty?
      puts "✅ MX record found"
      mx_record.each { |record| puts "   #{record}" }
    else
      puts "❌ MX record not found"
    end
  end

  def test_smtp_connection
    puts "\n🔌 Testing SMTP Connection..."
    
    begin
      smtp = Net::SMTP.new(@smtp_host, @smtp_port)
      smtp.enable_starttls
      
      puts "✅ SMTP server connection successful"
      puts "   Host: #{@smtp_host}"
      puts "   Port: #{@smtp_port}"
      
      # Test authentication
      smtp.start(@domain, ENV['BREVO_SMTP_USER'], ENV['BREVO_SMTP_PASSWORD'], :login) do |smtp|
        puts "✅ SMTP authentication successful"
      end
      
    rescue => e
      puts "❌ SMTP connection failed: #{e.message}"
    end
  end

  def test_email_headers
    puts "\n📋 Testing Email Headers..."
    
    begin
      mail = SellerCommunicationsMailer.with(seller: Seller.find(114)).general_update
      
      puts "✅ Email generation successful"
      puts "   Subject: #{mail.subject}"
      puts "   From: #{mail.from}"
      puts "   To: #{mail.to}"
      
      # Check for important headers
      important_headers = [
        'Message-ID', 'Return-Path', 'Organization', 
        'X-Mailer', 'List-Unsubscribe'
      ]
      
      important_headers.each do |header|
        if mail[header]
          puts "✅ #{header}: #{mail[header]}"
        else
          puts "⚠️  #{header}: Missing"
        end
      end
      
    rescue => e
      puts "❌ Email generation failed: #{e.message}"
    end
  end

  def test_email_content
    puts "\n📝 Testing Email Content..."
    
    begin
      mail = SellerCommunicationsMailer.with(seller: Seller.find(114)).general_update
      body = mail.body.raw_source
      
      # Check for spam triggers
      spam_triggers = [
        'FREE', 'WIN', 'URGENT', 'ACT NOW', 'LIMITED TIME',
        'CLICK HERE', 'BUY NOW', '$$$', 'MAKE MONEY'
      ]
      
      found_triggers = spam_triggers.select { |trigger| body.upcase.include?(trigger) }
      
      if found_triggers.empty?
        puts "✅ No obvious spam triggers found"
      else
        puts "⚠️  Potential spam triggers found:"
        found_triggers.each { |trigger| puts "   - #{trigger}" }
      end
      
      # Check content length
      if body.length > 1000
        puts "✅ Email content length is adequate (#{body.length} characters)"
      else
        puts "⚠️  Email content might be too short (#{body.length} characters)"
      end
      
      # Check for proper HTML structure
      if body.include?('<!DOCTYPE html>') && body.include?('</html>')
        puts "✅ Proper HTML structure found"
      else
        puts "❌ Missing proper HTML structure"
      end
      
    rescue => e
      puts "❌ Content analysis failed: #{e.message}"
    end
  end

  def send_test_email
    puts "\n📤 Sending Test Email..."
    
    begin
      seller = Seller.find(114)
      mail = SellerCommunicationsMailer.with(seller: seller).general_update
      
      # Add test headers
      mail['X-Test-Email'] = 'true'
      mail['X-Test-Timestamp'] = Time.current.iso8601
      
      mail.deliver_now
      
      puts "✅ Test email sent successfully!"
      puts "   To: #{mail.to}"
      puts "   Subject: #{mail.subject}"
      puts "   Message-ID: #{mail['Message-ID']}"
      
    rescue => e
      puts "❌ Test email failed: #{e.message}"
      puts "   Backtrace: #{e.backtrace.first(3).join("\n")}"
    end
  end

  def get_dns_record(domain, type)
    begin
      resolver = Net::DNS::Resolver.new
      answer = resolver.query(domain, type)
      
      case type
      when 'TXT'
        answer.answer.map { |record| record.data }
      when 'MX'
        answer.answer.map { |record| "#{record.preference} #{record.exchange}" }
      else
        answer.answer.map(&:to_s)
      end
    rescue => e
      puts "   DNS lookup failed for #{domain}: #{e.message}"
      nil
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = EmailDeliverabilityTester.new
  tester.run_all_tests
end
