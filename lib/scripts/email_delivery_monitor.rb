# Email delivery monitoring script
# This script will help track email delivery issues

puts "🔍 === EMAIL DELIVERY MONITORING ==="
puts "Time: #{Time.current}"
puts "=" * 50

# Check if emails are being sent to different providers
test_emails = [
  'victorquaint@gmail.com',
  'test@outlook.com',
  'test@yahoo.com'
]

test_emails.each do |email|
  puts "\n📧 Testing delivery to: #{email}"
  
  begin
    # Create a simple test email
    message = <<~EMAIL
      From: #{ENV['BREVO_EMAIL']}
      To: #{email}
      Subject: Carbon Cube Test Email - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
      
      This is a test email from Carbon Cube Kenya to verify delivery.
      
      Test Details:
      - Time: #{Time.current}
      - Sender: #{ENV['BREVO_EMAIL']}
      - SMTP: smtp-relay.brevo.com:587
      
      If you receive this email, the delivery system is working correctly.
      
      Best regards,
      Carbon Cube Kenya Team
    EMAIL
    
    # Send via Rails mailer
    seller = Seller.find(114)
    mail = SellerCommunicationsMailer.general_update(seller)
    mail.to = [email]
    mail.deliver_now
    
    puts "✅ Email sent successfully to #{email}"
    
  rescue => e
    puts "❌ Failed to send to #{email}: #{e.message}"
  end
end

puts "\n📋 DELIVERY CHECKLIST:"
puts "1. Check spam/junk folders in all email accounts"
puts "2. Check if emails are being filtered by email providers"
puts "3. Verify sender reputation with Brevo"
puts "4. Check Brevo dashboard for delivery statistics"
puts "5. Consider using a different sender domain"

puts "\n🎯 === MONITORING COMPLETE ==="
