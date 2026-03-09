# lib/scripts/review_campaign_final.rb
EXCLUDED = 'shangwejunior5@gmail.com'
sent_count = 0
errors = []

puts "🚀 Starting Review Request Campaign..."
puts "Exclude: #{EXCLUDED}"

# 1. Gathering Buyers
puts "\n--- Processing Buyers ---"
buyers_with_events = ClickEvent
  .where(event_type: 'Reveal-Seller-Details')
  .where.not(buyer_id: nil)
  .where(review_request_sent_at: nil)
  .group_by(&:buyer_id)

buyers_with_events.each do |buyer_id, events|
  buyer = events.first.buyer
  next unless buyer && !buyer.blocked? && !buyer.deleted?
  next if buyer.email == EXCLUDED

  products = events.map do |e|
    ad = e.ad
    next unless ad
    {
      title: ad.title,
      seller_name: ad.seller&.enterprise_name || ad.seller&.fullname || 'Seller',
      image_url: ad.media&.first || 'https://carboncube-ke.com/logo.png',
      review_url: MarketingMailer.review_url_for(ad)
    }
  end.compact.uniq { |p| p[:title] }

  next if products.empty?

  begin
    puts "Sending to Buyer: #{buyer.fullname} <#{buyer.email}> (#{products.size} products)"
    MarketingMailer.product_review_request(name: buyer.fullname, email: buyer.email, products: products).deliver_now
    
    # Mark as sent
    ClickEvent.where(id: events.map(&:id)).update_all(review_request_sent_at: Time.current)
    
    sent_count += 1
    sleep 3
  rescue => e
    puts "FAILED Buyer: #{buyer.email} - #{e.message}"
    errors << { email: buyer.email, error: e.message }
  end
end

# 2. Gathering Sellers
puts "\n--- Processing Sellers ---"
# Sellers are in metadata
seller_events_raw = ClickEvent
  .where(event_type: 'Reveal-Seller-Details')
  .where(buyer_id: nil)
  .where(review_request_sent_at: nil)
  .where("(metadata->>'user_role' = 'seller' OR metadata->>'user_role' = 'Seller')")
  .where("metadata->>'user_email' IS NOT NULL")

# Group by seller email/id
grouped_sellers = seller_events_raw.group_by { |e| e.metadata['user_email'] || e.metadata['user_id'] }

grouped_sellers.each do |key, events|
  email = events.first.metadata['user_email']
  next if email == EXCLUDED
  
  # Find seller object
  seller = Seller.find_by(email: email) || Seller.find_by(id: events.first.metadata['user_id'])
  next unless seller && !seller.blocked? && !seller.deleted?
  
  products = events.map do |e|
    ad = e.ad
    next unless ad
    {
      title: ad.title,
      seller_name: ad.seller&.enterprise_name || ad.seller&.fullname || 'Seller',
      image_url: ad.media&.first || 'https://carboncube-ke.com/logo.png',
      review_url: MarketingMailer.review_url_for(ad)
    }
  end.compact.uniq { |p| p[:title] }

  next if products.empty?

  name = seller.enterprise_name.presence || seller.fullname
  begin
    puts "Sending to Seller: #{name} <#{seller.email}> (#{products.size} products)"
    MarketingMailer.product_review_request(name: name, email: seller.email, products: products).deliver_now
    
    # Mark as sent
    ClickEvent.where(id: events.map(&:id)).update_all(review_request_sent_at: Time.current)
    
    sent_count += 1
    sleep 3
  rescue => e
    puts "FAILED Seller: #{seller.email} - #{e.message}"
    errors << { email: seller.email, error: e.message }
  end
end

puts "\n" + "=" * 50
puts "✅ Campaign Finished!"
puts "Sent: #{sent_count} emails"
if errors.any?
  puts "Errors: #{errors.size}"
end
