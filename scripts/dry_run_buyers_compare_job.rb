# Usage: bundle exec rails runner scripts/dry_run_buyers_compare_job.rb

puts "=========================================================="
puts "  DRY RUN: SendBuyersCompareCampaignJob"
puts "  Target Campaign: Help Buyers Make Faster Decisions"
puts "=========================================================="
puts "Executing dry-run check (NO emails will be sent)..."

result = SendBuyersCompareCampaignJob.new.perform(true)

puts "\n📊 DRY RUN AUDIT REPORT:"
puts "----------------------------------------------------------"
puts "  • Dry Run Mode:           #{result[:dry_run]}"
puts "  • Total Eligible Sellers: #{result[:total_eligible_sellers]}"
puts "  • Skipped (Already Sent): #{result[:already_sent_skipped]}"
puts "  • Would Receive Email:    #{result[:successfully_processed]}"
puts "  • Failed/Invalid:        #{result[:failed_count]}"
puts "  • Execution Timestamp:   #{result[:timestamp]}"
puts "----------------------------------------------------------"
puts "✅ Dry run verification completed successfully."
