#!/usr/bin/env ruby
# Dry run script for Verify Before You Buy campaign - ALL USERS
# Usage: rails runner scripts/dry_run_verify_before_buying_all.rb

puts "🚀 Starting Dry Run: Verify Before You Buy Campaign"
puts "=" * 60

# Count users
total_sellers = Seller.where(deleted: [false, nil]).count
total_buyers = Buyer.where(deleted: [false, nil]).count
total_users = total_sellers + total_buyers

puts "📊 User Statistics:"
puts "  Total Sellers: #{total_sellers}"
puts "  Total Buyers: #{total_buyers}"
puts "  Total Users: #{total_users}"
puts "-" * 60

# Check Redis for already sent
email_dedup_key = "campaign:verify_before_buying:sent_emails"
phone_dedup_key = "campaign:verify_before_buying:sent_phones"

already_sent_emails = RedisConnection.with { |conn| conn.smembers(email_dedup_key) } rescue []
already_sent_phones = RedisConnection.with { |conn| conn.smembers(phone_dedup_key) } rescue []

puts "📋 Deduplication Status:"
puts "  Emails already sent: #{already_sent_emails.size}"
puts "  Phones already sent: #{already_sent_phones.size}"
puts "-" * 60

# Process Sellers
puts "\n👔 Processing SELLERS:"
seller_count = 0
seller_skip_count = 0
seller_no_contact = 0

Seller.where(deleted: [false, nil]).find_each(batch_size: 100) do |seller|
  email = seller.email.to_s.strip.downcase
  phone = seller.phone_number.to_s.strip
  
  has_email = email.present? && email.include?('@')
  has_phone = phone.present?
  
  if !has_email && !has_phone
    seller_no_contact += 1
    next
  end
  
  email_already_sent = already_sent_emails.include?(email)
  phone_already_sent = already_sent_phones.include?(phone)
  
  if email_already_sent && phone_already_sent
    seller_skip_count += 1
    next
  end
  
  seller_count += 1
  
  # Simulate job parameters
  channels = {}
  channels[:whatsapp] = true if has_phone && !phone_already_sent
  channels[:email] = true if has_email && !email_already_sent
  
  puts "  ✓ #{seller.fullname || seller.enterprise_name || 'Unknown'}"
  puts "    Email: #{email} #{email_already_sent ? '(already sent)' : '(would send)'}"
  puts "    Phone: #{phone} #{phone_already_sent ? '(already sent)' : '(would send)'}"
  puts "    Channels: #{channels.keys.join(', ')}"
  puts "    Template: verify_before_buying_sellers_v1"
  puts
end

# Process Buyers
puts "\n🛒 Processing BUYERS:"
buyer_count = 0
buyer_skip_count = 0
buyer_no_contact = 0

Buyer.where(deleted: [false, nil]).find_each(batch_size: 100) do |buyer|
  email = buyer.email.to_s.strip.downcase
  phone = buyer.phone_number.to_s.strip
  
  has_email = email.present? && email.include?('@')
  has_phone = phone.present?
  
  if !has_email && !has_phone
    buyer_no_contact += 1
    next
  end
  
  email_already_sent = already_sent_emails.include?(email)
  phone_already_sent = already_sent_phones.include?(phone)
  
  if email_already_sent && phone_already_sent
    buyer_skip_count += 1
    next
  end
  
  buyer_count += 1
  
  # Simulate job parameters
  channels = {}
  channels[:whatsapp] = true if has_phone && !phone_already_sent
  channels[:email] = true if has_email && !email_already_sent
  
  puts "  ✓ #{buyer.fullname || buyer.username || 'Unknown'}"
  puts "    Email: #{email} #{email_already_sent ? '(already sent)' : '(would send)'}"
  puts "    Phone: #{phone} #{phone_already_sent ? '(already sent)' : '(would send)'}"
  puts "    Channels: #{channels.keys.join(', ')}"
  puts "    Template: verify_before_buying_buyers_v1"
  puts
end

# Summary
puts "=" * 60
puts "📊 DRY RUN SUMMARY"
puts "=" * 60
puts "Total Users Processed: #{total_users}"
puts
puts "SELLERS:"
puts "  Would send to: #{seller_count}"
puts "  Skip (already sent): #{seller_skip_count}"
puts "  No contact info: #{seller_no_contact}"
puts
puts "BUYERS:"
puts "  Would send to: #{buyer_count}"
puts "  Skip (already sent): #{buyer_skip_count}"
puts "  No contact info: #{buyer_no_contact}"
puts
puts "TOTAL WOULD SEND: #{seller_count + buyer_count}"
puts "TOTAL SKIP: #{seller_skip_count + buyer_skip_count}"
puts "TOTAL NO CONTACT: #{seller_no_contact + buyer_no_contact}"
puts "=" * 60
puts "✅ DRY RUN COMPLETE - No messages were actually sent"
puts "💡 To execute for real, set dry_run=false in the job parameters"
