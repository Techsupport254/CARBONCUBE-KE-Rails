#!/usr/bin/env ruby
# Script to send OTP to any user (Seller, Buyer, or Admin)
# Usage: rails runner lib/scripts/send_otp_to_user.rb

def send_otp_to_user(email, user_type = nil)
  # Find user by email
  user = case user_type&.downcase
         when 'seller'
           Seller.find_by(email: email)
         when 'buyer'
           Buyer.find_by(email: email)
         when 'admin'
           Admin.find_by(email: email)
         else
           # Try to find in any table
           Seller.find_by(email: email) || Buyer.find_by(email: email) || Admin.find_by(email: email)
         end

  unless user
    puts "❌ User with email '#{email}' not found"
    return false
  end

  # Generate OTP
  otp_code = rand.to_s[2..7] # 6-digit code
  expires_at = 10.minutes.from_now

  # Remove old OTPs for this email
  EmailOtp.where(email: email).delete_all

  # Create new OTP record
  otp_record = EmailOtp.create!(email: email, otp_code: otp_code, expires_at: expires_at)

  puts "📧 Sending OTP to: #{email} (#{user.fullname})"
  puts "👤 User Type: #{user.class.name}"
  puts "🔢 OTP Code: #{otp_code}"
  puts "⏰ Expires at: #{expires_at.strftime('%Y-%m-%d %H:%M:%S UTC')}"

  # Send OTP email
  OtpMailer.with(email: email, code: otp_code, fullname: user.fullname).send_otp.deliver_now

  puts "✅ OTP email sent successfully!"
  puts ""
  puts "OTP Details:"
  puts "  Email: #{email}"
  puts "  Code: #{otp_code}"
  puts "  User: #{user.fullname}"
  puts "  Expires: #{expires_at.strftime('%Y-%m-%d %H:%M:%S UTC')}"

  return {
    email: email,
    otp_code: otp_code,
    expires_at: expires_at,
    user: user,
    otp_record: otp_record
  }
end

# Example usage:
if __FILE__ == $0
  # You can call this script directly or use the function
  puts "=== OTP Sender Script ==="
  puts "Usage: send_otp_to_user('email@example.com', 'seller')"
  puts ""
  
  # Example: Send OTP to seller 114
  # send_otp_to_user('victorquaint@gmail.com', 'seller')
end
