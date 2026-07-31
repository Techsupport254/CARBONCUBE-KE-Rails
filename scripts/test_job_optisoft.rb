# Usage: bundle exec rails runner scripts/test_job_optisoft.rb

target_email = "optisoftkenya@gmail.com"

puts "=========================================================="
puts "  EXECUTING SIDEKIQ JOB PIPELINE FOR: #{target_email}"
puts "  Job Class: SendBuyersCompareCampaignJob"
puts "  Campaign: Help Buyers Make Faster Decisions"
puts "=========================================================="

# Execute live via the job's perform method (dry_run = false, target_email = "optisoftkenya@gmail.com")
result = SendBuyersCompareCampaignJob.new.perform(false, target_email)

puts "\n📊 JOB EXECUTION AUDIT REPORT:"
puts "----------------------------------------------------------"
puts "  • Dry Run Mode:           #{result[:dry_run]}"
puts "  • Target Email:           #{target_email}"
puts "  • Successfully Processed: #{result[:successfully_processed]}"
puts "  • Skipped (Idempotent):   #{result[:already_sent_skipped]}"
puts "  • Failed:                 #{result[:failed_count]}"
puts "  • Timestamp:              #{result[:timestamp]}"
puts "----------------------------------------------------------"

if result[:successfully_processed] > 0
  puts "✅ Sidekiq job successfully dispatched the email to #{target_email} via Brevo!"
elsif result[:already_sent_skipped] > 0
  puts "ℹ️ Sidekiq job skipped #{target_email} because idempotency rules detected it was already sent in this campaign key."
else
  puts "⚠️ Job failed to deliver. Check logs for details."
end
