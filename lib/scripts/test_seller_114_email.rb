# Test script for seller 114 email communication
# Run this in Rails console: rails console
# Then: load 'lib/scripts/test_seller_114_email.rb'

puts "🚀 Testing seller 114 email communication..."

# Find seller 114
seller = Seller.find_by(id: 114)

if seller.nil?
  puts "❌ Seller with ID 114 not found!"
  puts "Available sellers:"
  Seller.limit(5).each do |s|
    puts "  - ID: #{s.id}, Name: #{s.fullname}, Email: #{s.email}"
  end
  exit
end

puts "✅ Found seller: #{seller.fullname}"
puts "📧 Email: #{seller.email}"
puts "🏢 Enterprise: #{seller.enterprise_name}"
puts "📍 Location: #{seller.location}"

# Check analytics
puts "📊 Analytics:"
puts "  - Total Ads: #{seller.ads.count}"
puts "  - Total Reviews: #{seller.reviews.count}"
puts "  - Average Rating: #{seller.reviews.average(:rating)&.round(1) || 'N/A'}"
puts "  - Tier: #{seller.seller_tier&.tier_id || 'Free'}"

puts "\n📤 Testing email generation..."

begin
  # Test email generation
  mail = SellerCommunicationsMailer.with(seller: seller).general_update
  
  puts "✅ Email generated successfully!"
  puts "📋 Subject: #{mail.subject}"
  puts "📧 To: #{mail.to}"
  puts "📧 From: #{mail.from}"
  
  # Option 1: Queue the job (recommended for production)
  puts "\n🔄 Queuing email job..."
  SendSellerCommunicationJob.perform_later(seller.id, 'general_update')
  puts "✅ Email job queued successfully!"
  
  # Option 2: Send immediately (for testing)
  puts "\n📤 Sending email immediately for testing..."
  mail.deliver_now
  puts "✅ Email sent immediately!"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts "📋 Backtrace:"
  puts e.backtrace.first(5).join("\n")
end

puts "\n🎉 Test completed!"
puts "💡 Check #{seller.email} for the email"
puts "💡 To process queued jobs, run: rails jobs:work"
