# lib/tasks/phone_update_campaign.rake
# frozen_string_literal: true

namespace :campaign do
  desc "Execute phone/county completion campaign for sellers (Usage: rake campaign:request_phone_numbers[dry_run,week_number])"
  task :request_phone_numbers, [:dry_run, :week_number] => :environment do |_t, args|
    dry_run = args[:dry_run].nil? ? true : ActiveModel::Type::Boolean.new.cast(args[:dry_run])
    week_number = args[:week_number].present? ? args[:week_number].to_i : 1

    puts "=========================================================="
    puts "  RAKE TASK: campaign:request_phone_numbers"
    puts "  Dry Run: #{dry_run}"
    puts "  Week Iteration: Week #{week_number} / 4"
    puts "=========================================================="

    result = SendPhoneUpdateReminderJob.new.perform(dry_run, week_number)

    puts "\n📊 RAKE EXECUTION REPORT:"
    puts "----------------------------------------------------------"
    puts "  • Dry Run Mode:                  #{result[:dry_run]}"
    puts "  • Week Iteration:                Week #{result[:week_number]} / #{result[:max_weeks]}"
    puts "  • Sellers Missing Phone/County:  #{result[:total_eligible_sellers]}"
    puts "  • Skipped (Already Sent):        #{result[:already_sent_skipped]}"
    puts "  • Successfully Processed:        #{result[:successfully_processed]}"
    puts "  • Failed:                        #{result[:failed_count]}"
    puts "----------------------------------------------------------"

    if result[:failed_count] > 0
      puts "⚠️ Failure Details:"
      result[:failed_sellers].each do |failure|
        puts "   - Seller ##{failure[:seller_id]} (#{failure[:email]}): #{failure[:error]}"
      end
    end

    puts "✅ Rake task execution complete."
  end

  desc "Trigger live phone update campaign on deployment"
  task trigger_phone_update_on_deploy: :environment do
    puts "🚀 Deploy Hook: Triggering phone update campaign broadcast..."
    SendPhoneUpdateReminderJob.perform_later(false, 1)
    puts "✅ Enqueued SendPhoneUpdateReminderJob in Sidekiq queue."
  end
end
