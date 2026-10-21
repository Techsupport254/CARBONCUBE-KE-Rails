# frozen_string_literal: true

namespace :admin do
  desc 'Send a test WhatsApp updates invite email to the test contact. ' \
       'Usage: admin:send_whatsapp_updates_invite_test[email,reminder_number]'
  task :send_whatsapp_updates_invite_test, %i[email reminder_number] => :environment do |_t, args|
    test_email = args[:email].presence || 'kiruivictor097@gmail.com'
    reminder_num = args[:reminder_number].present? ? args[:reminder_number].to_i : 0

    puts '=== WHATSAPP UPDATES INVITE EMAIL — TEST MODE ==='
    puts "Recipient Email: #{test_email}"
    puts "Stage:           #{reminder_num.zero? ? 'Initial Invite (T+2d)' : "Reminder #{reminder_num} (T+5d)"}"
    puts '================================================'

    seller = Seller.find_by(email: test_email) || Seller.first
    abort 'ERROR: no recipient found in database' unless seller

    mail = MarketingMailer.whatsapp_updates_invite(
      recipient: seller,
      reminder_number: reminder_num
    )

    mail.to = [test_email]
    mail.deliver_now

    puts "Sent successfully! Subject: #{mail.subject}"
    puts '================================================'
  end

  desc 'Run WhatsApp updates email invite and reminder campaign (dry_run defaults to true). ' \
       'Usage: admin:send_whatsapp_updates_invite_campaign[dry_run]'
  task :send_whatsapp_updates_invite_campaign, [:dry_run] => :environment do |_t, args|
    dry_run = (args[:dry_run] || ENV['DRY_RUN']) != 'false'

    puts '=== WHATSAPP UPDATES INVITE CAMPAIGN ==='
    puts "Dry Run Mode: #{dry_run}"
    puts '========================================'

    stats = SendWhatsappUpdatesInviteJob.new.perform(dry_run: dry_run)

    puts ''
    puts '=== INITIAL INVITES (T+2d) ==='
    puts "Eligible:          #{stats[:initial_eligible]}"
    puts "Queued/Sent:       #{stats[:initial_queued]}"
    puts "Skipped (engaged): #{stats[:initial_skipped_engaged]}"
    puts "Skipped (already): #{stats[:initial_skipped_duplicate]}"
    puts ''
    puts '=== REMINDERS (T+5d) ==='
    puts "Eligible:          #{stats[:reminder_eligible]}"
    puts "Queued/Sent:       #{stats[:reminder_queued]}"
    puts "Skipped (engaged): #{stats[:reminder_skipped_engaged]}"
    puts "Skipped (already): #{stats[:reminder_skipped_duplicate]}"
    puts ''
    puts "Failed:            #{stats[:failed]}"
    puts '========================================'
  end
end
