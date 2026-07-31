# Usage: rails runner scripts/send_buyers_compare_email.rb

test_email = "optisoftkenya@gmail.com"

puts "Attempting to send 'Help Buyers Make Faster Decisions' test email to: #{test_email}"

seller = Seller.find_by(email: test_email)

if seller.nil?
  puts "⚠️ Seller #{test_email} not found in database. Using mock object..."
  seller = OpenStruct.new(
    email: test_email,
    fullname: "Optisoft Kenya Team",
    enterprise_name: "Optisoft Kenya"
  )
end

begin
  mail = SellerCommunicationsMailer.with(
    seller: seller
  ).buyers_compare_before_contact.deliver_now
  
  puts "✅ Success! 'Help Buyers Make Faster Decisions' email sent to #{test_email}"
rescue => e
  puts "❌ Failed to send email: #{e.message}"
  puts e.backtrace.first(10)
end
