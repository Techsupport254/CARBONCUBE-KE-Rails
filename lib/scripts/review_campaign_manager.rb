# Review Request Campaign Manager
# This script identifies buyers who have revealed seller details and drafts a review request email.
# It tracks the sent timestamp in ClickEvent to avoid duplicate outreach.

def run_campaign(limit: 100, simulate: true)
  puts "🚀 Starting Review Request Campaign (Simulation: #{simulate})"
  puts "--------------------------------------------------------"

  # Base tracking parameters
  utm_params = "utm_source=email&utm_medium=retention&utm_campaign=review_request"

  # Find 'Reveal-Seller-Details' events for registered buyers that haven't received a request yet
  reveal_events = ClickEvent
    .where(event_type: 'Reveal-Seller-Details')
    .where.not(buyer_id: nil)
    .where(review_request_sent_at: nil)
    .includes(:buyer, ad: :seller)
    .limit(limit)

  if reveal_events.empty?
    puts "✅ No new reveals found. All users have been notified or no data exists."
    return
  end

  # Group by buyer to send a single email with multiple products
  grouped_reveals = reveal_events.group_by(&:buyer_id)

  summary = []

  grouped_reveals.each do |buyer_id, events|
    buyer = events.first.buyer
    next unless buyer && buyer.email.present?

    # Exclude obvious internal test accounts / high volume revealers if needed
    # next if events.size > 20 && buyer.email.include?('shangwe')

    products = events.map do |re|
      ad = re.ad
      next unless ad
      
      # Use first media item or fallback
      img_url = ad.media&.first
      img_url = "https://carbon-v2.com/favicon.svg" if img_url.blank?
      
      # Determine review URL with UTMs
      base_url = "https://carbon-v2.com/ads/#{ad.id}" # Using ID for safety as slug might not be guaranteed
      full_review_url = "#{base_url}?review=true&#{utm_params}"

      {
        id: ad.id,
        title: ad.title,
        seller_name: ad.seller&.enterprise_name || ad.seller&.fullname || "a Carbon Cube Kenya Seller",
        image_url: img_url,
        review_url: full_review_url
      }
    end.compact.uniq { |p| p[:id] }

    next if products.empty?

    # Draft for log/report
    summary << {
      recipient: "#{buyer.fullname} <#{buyer.email}>",
      subject: "Hey #{buyer.fullname.split.first}, was it a good deal on Carbon Cube Kenya?",
      product_count: products.size,
      product_titles: products.map { |p| p[:title] }.join(", ")
    }

    # Mark as sent if not simulating
    unless simulate
      # Batch update the specific reveal events we've processed
      ClickEvent.where(id: events.map(&:id)).update_all(review_request_sent_at: Time.current)
    end
  end

  # Report results
  puts "📊 Campaign Summary:"
  puts "Unique users found: #{summary.size}"
  puts "Total click events processed: #{reveal_events.size}"
  puts "--------------------------------------------------------"
  
  summary.each_with_index do |s, i|
    puts "#{i+1}. SEND TO: #{s[:recipient]}"
    puts "   SUBJECT: #{s[:subject]}"
    puts "   ITEMS:   #{s[:product_count]} products (#{s[:product_titles]})"
    puts ""
  end

  if simulate
    puts "⚠️  SIMULATION ONLY. No database changes were made."
    puts "   To mark as SENT, run: run_campaign(simulate: false)"
  else
    puts "✅ SUCCESS. #{reveal_events.size} click events marked with review_request_sent_at timestamp."
  end
end

# Run the simulation
run_campaign(simulate: true)
