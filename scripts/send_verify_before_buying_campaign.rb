#!/usr/bin/env ruby
# Execute Verify Before You Buy campaign - ALL USERS
# Usage: rails runner scripts/send_verify_before_buying_campaign.rb

puts "🚀 Starting Verify Before You Buy Campaign Execution"
puts "=" * 60
puts "⚠️  THIS WILL SEND REAL MESSAGES TO ALL USERS"
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
seller_sent = 0
seller_skip = 0
seller_error = 0

Seller.where(deleted: [false, nil]).find_each(batch_size: 50) do |seller|
  email = seller.email.to_s.strip.downcase
  phone = seller.phone_number.to_s.strip
  
  has_email = email.present? && email.include?('@')
  has_phone = phone.present?
  
  if !has_email && !has_phone
    seller_skip += 1
    next
  end
  
  email_already_sent = already_sent_emails.include?(email)
  phone_already_sent = already_sent_phones.include?(phone)
  
  if email_already_sent && phone_already_sent
    seller_skip += 1
    next
  end
  
  begin
    channels = {}
    channels[:whatsapp] = true if has_phone && !phone_already_sent
    channels[:in_app] = false # Disable in-app to avoid double messaging
    channels[:email] = true if has_email && !email_already_sent
    
    # Queue the job with dry_run=false
    SendVerifyBeforeBuyingCampaignJob.perform_later(seller.id, 'seller', false, channels)
    
    seller_sent += 1
    print "."
    
    # Small delay to avoid overwhelming Sidekiq
    sleep 0.1 if seller_sent % 100 == 0
    
  rescue => e
    seller_error += 1
    puts "\n❌ Error queueing for seller #{seller.id}: #{e.message}"
  end
end

puts "\n✅ Sellers processed: #{seller_sent} sent, #{seller_skip} skipped, #{seller_error} errors"

# Process Buyers
puts "\n🛒 Processing BUYERS:"
buyer_sent = 0
buyer_skip = 0
buyer_error = 0

Buyer.where(deleted: [false, nil]).find_each(batch_size: 50) do |buyer|
  email = buyer.email.to_s.strip.downcase
  phone = buyer.phone_number.to_s.strip
  
  has_email = email.present? && email.include?('@')
  has_phone = phone.present?
  
  if !has_email && !has_phone
    buyer_skip += 1
    next
  end
  
  email_already_sent = already_sent_emails.include?(email)
  phone_already_sent = already_sent_phones.include?(phone)
  
  if email_already_sent && phone_already_sent
    buyer_skip += 1
    next
  end
  
  begin
    channels = {}
    channels[:whatsapp] = true if has_phone && !phone_already_sent
    channels[:in_app] = false # Disable in-app to avoid double messaging
    channels[:email] = true if has_email && !email_already_sent
    
    # Queue the job with dry_run=false
    SendVerifyBeforeBuyingCampaignJob.perform_later(buyer.id, 'buyer', false, channels)
    
    buyer_sent += 1
    print "."
    
    # Small delay to avoid overwhelming Sidekiq
    sleep 0.1 if buyer_sent % 100 == 0
    
  rescue => e
    buyer_error += 1
    puts "\n❌ Error queueing for buyer #{buyer.id}: #{e.message}"
  end
end

puts "\n✅ Buyers processed: #{buyer_sent} sent, #{buyer_skip} skipped, #{buyer_error} errors"

# Summary
puts "\n" + "=" * 60
puts "📊 CAMPAIGN EXECUTION SUMMARY"
puts "=" * 60
puts "Total Users Processed: #{total_users}"
puts
puts "SELLERS:"
puts "  Jobs queued: #{seller_sent}"
puts "  Skipped (already sent/no contact): #{seller_skip}"
puts "  Errors: #{seller_error}"
puts
puts "BUYERS:"
puts "  Jobs queued: #{buyer_sent}"
puts "  Skipped (already sent/no contact): #{buyer_skip}"
puts "  Errors: #{buyer_error}"
puts
puts "TOTAL JOBS QUEUED: #{seller_sent + buyer_sent}"
puts "TOTAL SKIPPED: #{seller_skip + buyer_skip}"
puts "TOTAL ERRORS: #{seller_error + buyer_error}"
puts "=" * 60
puts "✅ CAMPAIGN EXECUTION COMPLETE"
puts "💡 Jobs are now processing in Sidekiq queue: broadcast"
puts "📊 Check Sidekiq dashboard for progress and any failures"
