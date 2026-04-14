
# Run this to check shop share statistics
analytic_count = Analytic.where(utm_campaign: 'shop_share').count
puts "Total Shop Share Visits: #{analytic_count}"

# Break down by source if available
source_counts = Analytic.where(utm_campaign: 'shop_share').group(:utm_source).count
puts "\nBreakdown by Source:"
source_counts.each do |source, count|
  puts "#{source || 'direct'}: #{count}"
end

# Check for ad_share too
ad_share_count = Analytic.where(utm_campaign: 'product_share').count
puts "\nTotal Product Share Visits: #{ad_share_count}"
