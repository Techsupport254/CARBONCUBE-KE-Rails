#!/usr/bin/env ruby
# Test script for Verify Before You Buy campaign
# Usage: rails runner scripts/test_verify_before_buying_campaign.rb

test_email = 'optisoftkenya@gmail.com'

# Find user by email (check both buyers and sellers)
user = Seller.find_by(email: test_email) || Buyer.find_by(email: test_email)

if user.nil?
  puts "❌ User not found with email: #{test_email}"
  puts "Checking for seller..."
  seller = Seller.find_by(email: test_email)
  if seller
    puts "✅ Found seller: #{seller.fullname} (#{seller.id})"
    user = seller
    user_type = 'seller'
  else
    puts "❌ No seller found either. Creating test seller..."
    user = Seller.create!(
      email: test_email,
      fullname: 'Test User',
      enterprise_name: 'Optisoft Kenya',
      phone_number: '+254700000000'
    )
    user_type = 'seller'
    puts "✅ Created test seller: #{user.fullname} (#{user.id})"
  end
else
  user_type = user.is_a?(Seller) ? 'seller' : 'buyer'
  puts "✅ Found #{user_type}: #{user.fullname} (#{user.id})"
end

puts "\n🚀 Sending Verify Before You Buy campaign to #{test_email}"
puts "User Type: #{user_type}"
puts "User ID: #{user.id}"
puts "Channels: { whatsapp: true }"
puts "Dry Run: false"
puts "-" * 50

# Queue the job
SendVerifyBeforeBuyingCampaignJob.perform_later(user.id, user_type, false, { whatsapp: true })

puts "✅ Campaign job queued successfully!"
puts "Job will send WhatsApp template to #{user.phone_number || 'no phone number'}"
puts "UTM Campaign: verify_before_buying"
