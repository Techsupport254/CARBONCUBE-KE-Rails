# frozen_string_literal: true

# Catalog upload reminder campaign — nudges sellers to send us their product
# catalogs across WhatsApp + email + push + in-app.
#
#   bin/rails admin:send_catalog_upload_reminder_test
#   bin/rails admin:send_catalog_upload_reminder_to_new_sellers              # dry run
#   bin/rails 'admin:send_catalog_upload_reminder_to_new_sellers[false]'     # LIVE send
namespace :admin do
  desc 'Send the catalog upload reminder to the test contact only ' \
       '(kiruivictor097@gmail.com / 0716404137)'
  task send_catalog_upload_reminder_test: :environment do
    test_email = 'kiruivictor097@gmail.com'
    test_phone = '0716404137'

    puts '=== CATALOG UPLOAD REMINDER — TEST MODE ==='
    puts "Email:    #{test_email}"
    puts "WhatsApp: #{test_phone}"
    puts '==========================================='

    seller = Seller.find_by(email: test_email) || Seller.first
    abort "ERROR: no seller found in database" unless seller

    puts "Seller found: #{seller.enterprise_name.presence || seller.fullname} (id #{seller.id})"
    puts 'Sending inline on all four channels...'

    result = SendCatalogUploadReminderJob.perform_now(
      seller.id,
      {},
      target_phone: test_phone,
      target_email: test_email
    )

    puts ''
    puts '=== RESULTS ==='
    result&.each { |channel, r| puts "#{channel.to_s.ljust(14)} #{r.inspect}" }
    puts '==============='
  end

  desc 'Run the 1-week catalog upload reminder for new sellers without products. ' \
       'Usage: admin:send_catalog_upload_reminder_to_new_sellers[dry_run,min_age_hours,max_age_hours]'
  task :send_catalog_upload_reminder_to_new_sellers, %i[dry_run min_age_hours max_age_hours] => :environment do |_t, args|
    dry_run = (args[:dry_run] || ENV['DRY_RUN']) != 'false'
    min_age = args[:min_age_hours].present? ? args[:min_age_hours].to_i : SendCatalogUploadReminderToNewSellersJob::MIN_AGE_HOURS
    max_age = args[:max_age_hours].present? ? args[:max_age_hours].to_i : SendCatalogUploadReminderToNewSellersJob::MAX_AGE_HOURS

    puts '=== 1-WEEK CATALOG UPLOAD REMINDER (NEW SELLERS) ==='
    puts "Dry Run Mode:   #{dry_run}"
    puts "Age window:     #{min_age}h to #{max_age}h ago (#{(min_age / 24.0).round(1)} to #{(max_age / 24.0).round(1)} days)"
    puts '====================================================='

    stats = SendCatalogUploadReminderToNewSellersJob.new.perform(
      dry_run: dry_run,
      min_age_hours: min_age,
      max_age_hours: max_age
    )

    puts ''
    puts '=== SUMMARY ==='
    puts "Eligible in window:  #{stats[:eligible]}"
    puts "Queued for delivery: #{stats[:queued]}"
    puts "Skipped (has ads):   #{stats[:skipped_has_ads]}"
    puts "Skipped (duplicate): #{stats[:skipped_duplicate]}"
    puts "Failed:              #{stats[:failed]}"
    puts '==============='
  end
end
