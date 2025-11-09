namespace :clicks do
  desc "Associate guest click events with buyers and sellers based on device hash"
  task associate_guest_clicks: :environment do
    puts "Starting guest click association for all users..."
    puts ""
    
    # Process buyers
    puts "=== Processing Buyers ==="
    total_buyers = Buyer.count
    processed_buyers = 0
    total_buyer_clicks = 0
    
    Buyer.find_each do |buyer|
      processed_buyers += 1
      clicks_before = buyer.click_events.count
      
      associated = GuestClickAssociationService.associate_clicks_with_user(buyer)
      total_buyer_clicks += associated
      
      clicks_after = buyer.click_events.count
      if clicks_after > clicks_before
        puts "[#{processed_buyers}/#{total_buyers}] Buyer #{buyer.email}: #{clicks_before} -> #{clicks_after} clicks (+#{associated})"
      end
      
      # Progress indicator
      if processed_buyers % 100 == 0
        puts "Processed #{processed_buyers}/#{total_buyers} buyers..."
      end
    end
    
    puts ""
    puts "✅ Buyers: Associated #{total_buyer_clicks} guest clicks across #{processed_buyers} buyers."
    puts ""
    
    # Process sellers
    puts "=== Processing Sellers ==="
    total_sellers = Seller.count
    processed_sellers = 0
    total_seller_clicks = 0
    
    Seller.find_each do |seller|
      processed_sellers += 1
      
      # Count clicks associated with seller (in metadata)
      clicks_before = ClickEvent
        .where("metadata->>'seller_id' = ?", seller.id.to_s)
        .count
      
      associated = GuestClickAssociationService.associate_clicks_with_user(seller)
      total_seller_clicks += associated
      
      clicks_after = ClickEvent
        .where("metadata->>'seller_id' = ?", seller.id.to_s)
        .count
      
      if clicks_after > clicks_before
        puts "[#{processed_sellers}/#{total_sellers}] Seller #{seller.email}: #{clicks_before} -> #{clicks_after} clicks (+#{associated})"
      end
      
      # Progress indicator
      if processed_sellers % 100 == 0
        puts "Processed #{processed_sellers}/#{total_sellers} sellers..."
      end
    end
    
    puts ""
    puts "✅ Sellers: Associated #{total_seller_clicks} guest clicks across #{processed_sellers} sellers."
    puts ""
    puts "=== Summary ==="
    puts "Total buyers processed: #{processed_buyers}"
    puts "Total buyer clicks associated: #{total_buyer_clicks}"
    puts "Total sellers processed: #{processed_sellers}"
    puts "Total seller clicks associated: #{total_seller_clicks}"
    puts "Grand total clicks associated: #{total_buyer_clicks + total_seller_clicks}"
    puts ""
    puts "✅ Completed!"
  end
end

