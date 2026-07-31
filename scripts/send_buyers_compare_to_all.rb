# Usage: bundle exec rails runner scripts/send_buyers_compare_to_all.rb

puts "=========================================================="
puts "  STARTING LIVE CAMPAIGN BROADCAST TO ALL ACTIVE SELLERS"
puts "  Job Class: SendBuyersCompareCampaignJob"
puts "  Campaign: Help Buyers Make Faster Decisions"
puts "=========================================================="
puts "Launching live dispatch pipeline..."

# Execute live broadcast for all active sellers (dry_run: false)
result = SendBuyersCompareCampaignJob.new.perform(false)

puts "\n📊 FINAL CAMPAIGN BROADCAST REPORT:"
puts "----------------------------------------------------------"
puts "  • Dry Run Mode:           #{result[:dry_run]}"
puts "  • Total Eligible Sellers: #{result[:total_eligible_sellers]}"
puts "  • Successfully Sent:     #{result[:successfully_processed]}"
puts "  • Skipped (Already Sent): #{result[:already_sent_skipped]}"
puts "  • Failed:                 #{result[:failed_count]}"
puts "  • Timestamp:              #{result[:timestamp]}"
puts "----------------------------------------------------------"

if result[:failed_count] > 0
  puts "⚠️ Failures recorded for #{result[:failed_count]} sellers:"
  result[:failed_sellers].first(10).each do |failure|
    puts "   - Seller ##{failure[:seller_id]} (#{failure[:email]}): #{failure[:error]}"
  end
end

puts "✅ Live campaign broadcast completed."
