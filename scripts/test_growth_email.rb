# Test script to send seller growth initiative email to the specified test user ONLY.
# Usage: rails runner scripts/test_growth_email.rb

test_email = "optisoftkenya@gmail.com"

puts "Attempting to send seller growth initiative test email to: #{test_email}"

# Try to find the actual seller record
seller = Seller.find_by(email: test_email)

if seller.nil?
  puts "⚠️ Seller #{test_email} not found in database. Using a local mock object for testing..."
  seller = OpenStruct.new(
    email: test_email,
    fullname: "Optisoft Kenya Team",
    enterprise_name: "Optisoft Kenya"
  )
end

begin
  SellerCommunicationsMailer.with(
    seller: seller
  ).seller_growth_initiative.deliver_now
  
  puts "✅ Success! Growth Initiative email sent to #{test_email}"
rescue => e
  puts "❌ Failed to send email: #{e.message}"
  puts e.backtrace.first(5)
end
