# Usage: bundle exec rails runner scripts/dry_run_phone_update_campaign.rb

puts "=========================================================="
puts "  DRY RUN: SendPhoneUpdateReminderJob"
puts "  Campaign: Request Phone Numbers for Sellers Missing Phone"
puts "  Frequency: 1x / Week for 4 Weeks (Dynamic Exclusion Active)"
puts "=========================================================="
puts "Executing dry-run check across 4-week iteration plan (NO emails will be sent)..."

(1..4).each do |week|
  result = SendPhoneUpdateReminderJob.new.perform(true, week)

  puts "\n📊 WEEK #{week} AUDIT REPORT:"
  puts "----------------------------------------------------------"
  puts "  • Dry Run Mode:                  #{result[:dry_run]}"
  puts "  • Iteration Week:                Week #{result[:week_number]} / #{result[:max_weeks]}"
  puts "  • Sellers Missing Phone Number:  #{result[:total_sellers_missing_phone]}"
  puts "  • Skipped (Already Sent):        #{result[:already_sent_skipped]}"
  puts "  • Would Receive Email:           #{result[:successfully_processed]}"
  puts "  • Failed / Invalid:              #{result[:failed_count]}"
  puts "----------------------------------------------------------"
end

puts "\n✅ Phone update campaign dry run completed successfully."
puts "   (Campaign is configured and ready. It has NOT been started live.)"
