# lib/tasks/broadcast.rake
# frozen_string_literal: true

namespace :broadcast do
  desc "Broadcast the app-update announcement to all buyers and sellers (Usage: rake broadcast:app_update[dry_run])"
  task :app_update, [:dry_run] => :environment do |_t, args|
    dry_run = args[:dry_run].nil? || ActiveModel::Type::Boolean.new.cast(args[:dry_run])

    puts "=========================================================="
    puts "  RAKE TASK: broadcast:app_update"
    puts "  Dry Run: #{dry_run}"
    puts "=========================================================="

    result = BroadcastAppUpdateJob.new.perform(dry_run: dry_run)

    puts "\n📊 RAKE EXECUTION REPORT:"
    puts "----------------------------------------------------------"
    puts "  • Dry Run Mode:            #{dry_run}"
    puts "  • Eligible Users:          #{result[:eligible]}"
    puts "  • Skipped (Already Sent):  #{result[:skipped_duplicate]}"
    puts "  • Notified (In-App):       #{result[:notified]}"
    puts "  • Push Sent (FCM):         #{result[:pushed]}"
    puts "  • Failed:                  #{result[:failed]}"
    puts "----------------------------------------------------------"
    puts "✅ Rake task execution complete."
  end
end
