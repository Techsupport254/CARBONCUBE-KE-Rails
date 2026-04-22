# scripts/bulk_send_app_promo.rb

puts "🚀 Starting Bulk App Promo Send-Out..."
puts "──────────────────────────────────────"

total_sellers = Seller.count
total_buyers = Buyer.count

puts "📊 Target: #{total_sellers} Sellers and #{total_buyers} Buyers"

target_type = ARGV[0] # Get 'sellers' or 'buyers' from command line
if target_type.present?
  puts "🎯 Target limited to: #{target_type.capitalize}"
end

# 1. Process Sellers
if target_type.blank? || target_type.downcase == 'sellers' || target_type.downcase == 'seller'
  puts "\n📦 Scheduling Sellers..."
  seller_count = 0
  Seller.find_each(batch_size: 1000) do |seller|
    SendSellerCommunicationJob.perform_later(seller.id.to_s, 'app_promo', { email: true, whatsapp: false }, nil, nil, 'seller')
    seller_count += 1
    if seller_count % 10 == 0
      print "\r   Scheduled #{seller_count}/#{total_sellers} sellers..."
      $stdout.flush
    end
  end
  puts "\n✅ Done with Sellers."
else
  seller_count = 0
  puts "\n⏭️ Skipping Sellers."
end

# 2. Process Buyers
if target_type.blank? || target_type.downcase == 'buyers' || target_type.downcase == 'buyer'
  puts "\n👤 Scheduling Buyers..."
  buyer_count = 0
  Buyer.find_each(batch_size: 1000) do |buyer|
    SendSellerCommunicationJob.perform_later(buyer.id.to_s, 'app_promo', { email: true, whatsapp: false }, nil, nil, 'buyer')
    buyer_count += 1
    if buyer_count % 10 == 0
      print "\r   Scheduled #{buyer_count}/#{total_buyers} buyers..."
      $stdout.flush
    end
  end
  puts "\n✅ Done with Buyers."
else
  buyer_count = 0
  puts "\n⏭️ Skipping Buyers."
end

puts "\n🎯 Total Scheduled in this run: #{seller_count + buyer_count} communications."
puts "Check your Sidekiq dashboard or logs to monitor real-time delivery."
