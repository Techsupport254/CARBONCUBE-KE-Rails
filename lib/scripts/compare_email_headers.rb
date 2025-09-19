#!/usr/bin/env ruby
# Script to compare headers between OTP and Seller Communication emails
# Usage: rails runner lib/scripts/compare_email_headers.rb

puts "🔍 === EMAIL HEADERS COMPARISON ==="
puts "Time: #{Time.current}"
puts "=" * 60

# Find seller 114
seller = Seller.find_by(id: 114)
unless seller
  puts "❌ Seller 114 not found!"
  exit
end

puts "📧 Testing with seller: #{seller.fullname} (#{seller.email})"
puts ""

# Test 1: Generate OTP email
puts "1️⃣ === OTP EMAIL HEADERS ==="
begin
  otp_code = "123456"
  otp_mail = OtpMailer.with(email: seller.email, code: otp_code, fullname: seller.fullname).send_otp
  
  puts "✅ OTP Email generated successfully"
  puts "📋 Subject: #{otp_mail.subject}"
  puts "📧 To: #{otp_mail.to}"
  puts "📧 From: #{otp_mail.from}"
  puts ""
  
  # Check headers
  puts "📋 OTP Email Headers:"
  puts "  Message-ID: #{otp_mail['Message-ID']}"
  puts "  In-Reply-To: #{otp_mail['In-Reply-To'] || 'nil'}"
  puts "  References: #{otp_mail['References'] || 'nil'}"
  puts "  Precedence: #{otp_mail['Precedence'] || 'nil'}"
  puts "  X-Mailer: #{otp_mail['X-Mailer'] || 'nil'}"
  puts "  Return-Path: #{otp_mail['Return-Path'] || 'nil'}"
  puts "  Organization: #{otp_mail['Organization'] || 'nil'}"
  puts ""
  
rescue => e
  puts "❌ OTP Email generation failed: #{e.message}"
end

# Test 2: Generate Seller Communication email
puts "2️⃣ === SELLER COMMUNICATION EMAIL HEADERS ==="
begin
  seller_mail = SellerCommunicationsMailer.with(seller: seller).general_update
  
  puts "✅ Seller Communication Email generated successfully"
  puts "📋 Subject: #{seller_mail.subject}"
  puts "📧 To: #{seller_mail.to}"
  puts "📧 From: #{seller_mail.from}"
  puts ""
  
  # Check headers
  puts "📋 Seller Communication Email Headers:"
  puts "  Message-ID: #{seller_mail['Message-ID']}"
  puts "  In-Reply-To: #{seller_mail['In-Reply-To'] || 'nil'}"
  puts "  References: #{seller_mail['References'] || 'nil'}"
  puts "  Precedence: #{seller_mail['Precedence'] || 'nil'}"
  puts "  X-Mailer: #{seller_mail['X-Mailer'] || 'nil'}"
  puts "  Return-Path: #{seller_mail['Return-Path'] || 'nil'}"
  puts "  Organization: #{seller_mail['Organization'] || 'nil'}"
  puts ""
  
rescue => e
  puts "❌ Seller Communication Email generation failed: #{e.message}"
end

# Test 3: Send both emails and compare delivery
puts "3️⃣ === SENDING BOTH EMAILS FOR COMPARISON ==="
begin
  puts "📤 Sending OTP email..."
  otp_mail.deliver_now
  puts "✅ OTP email sent!"
  
  puts "📤 Sending Seller Communication email..."
  seller_mail.deliver_now
  puts "✅ Seller Communication email sent!"
  
  puts ""
  puts "📧 Check #{seller.email} for both emails"
  puts "💡 Compare how they appear in the inbox"
  
rescue => e
  puts "❌ Email sending failed: #{e.message}"
end

puts ""
puts "🎯 === COMPARISON COMPLETE ==="
puts "💡 Check the inbox to see which emails appear as NEW"
