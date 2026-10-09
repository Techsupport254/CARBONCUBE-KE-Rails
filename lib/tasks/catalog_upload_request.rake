# frozen_string_literal: true

# Catalog upload request campaign — asks sellers to send us their product
# catalogs across WhatsApp + email + push + in-app.
#
#   bin/rails admin:send_catalog_upload_request_test     # test contact ONLY
#   bin/rails admin:send_catalog_upload_to_all           # dry run (counts)
#   bin/rails admin:send_catalog_upload_to_all[false]    # LIVE send
namespace :admin do
  desc 'Send the catalog upload request to the test contact only ' \
       '(kiruivictor097@gmail.com / 0716404137)'
  task send_catalog_upload_request_test: :environment do
    test_email = 'kiruivictor097@gmail.com'
    test_phone = '0716404137'

    puts '=== CATALOG UPLOAD REQUEST — TEST MODE ==='
    puts "Email:    #{test_email}"
    puts "WhatsApp: #{test_phone}"
    puts '=========================================='

    seller = Seller.find_by(email: test_email)
    abort "ERROR: test seller #{test_email} not found" unless seller

    puts "Seller found: #{seller.enterprise_name.presence || seller.fullname} (id #{seller.id})"
    puts 'Sending inline on all four channels...'

    result = SendCatalogUploadRequestJob.perform_now(
      seller.id,
      {},
      target_phone: test_phone,
      target_email: test_email
    )

    puts ''
    puts '=== RESULTS ==='
    result&.each { |channel, r| puts "#{channel.to_s.ljust(12)} #{r.inspect}" }
    puts '==============='
  end

  desc 'Send the catalog upload request to ALL active sellers ' \
       '(WhatsApp + email + push + in-app). ' \
       'Usage: admin:send_catalog_upload_to_all[dry_run,send_at] — ' \
       'dry_run defaults to true; send_at is optional, e.g. "2026-10-10 09:00"'
  task :send_catalog_upload_to_all, [:dry_run, :send_at] => :environment do |_t, args|
    dry_run = (args[:dry_run] || ENV['DRY_RUN']) != 'false'
    send_at = args[:send_at].presence || ENV['SEND_AT']
    title = SendCatalogUploadRequestJob::NOTIFICATION_TITLE

    send_at_time = nil
    if send_at.present?
      send_at_time = Time.zone.parse(send_at)
      abort "ERROR: could not parse send_at '#{send_at}'" if send_at_time.nil?
      abort "ERROR: send_at #{send_at_time} is in the past" if send_at_time <= Time.current
    end

    puts '=== CATALOG UPLOAD REQUEST TO ALL SELLERS ==='
    puts "Dry Run Mode: #{dry_run}"
    puts "Scheduled for: #{send_at_time || 'immediate'}"
    puts '============================================='

    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
    already_notified = Notification.where(recipient_type: 'Seller', title: title)
                                   .select(:recipient_id)
    remaining = sellers.where.not(id: already_notified).count

    puts "Total active sellers: #{sellers.count}"
    puts "Already notified:     #{sellers.count - remaining}"
    puts "Remaining:            #{remaining}"

    if remaining.zero?
      puts 'Every active seller has already received this campaign. Nothing to do.'
      next
    end

    puts ''
    if dry_run
      puts 'DRY RUN — nothing will be sent.'
      puts 'To go live now, run:'
      puts '  bin/rails admin:send_catalog_upload_to_all[false]'
      puts 'To schedule for later, e.g. tomorrow 9am:'
      puts '  bin/rails \'admin:send_catalog_upload_to_all[false,2026-10-10 09:00]\''
    else
      puts "LIVE RUN — #{send_at_time ? "scheduled for #{send_at_time}" : 'sending now'} " \
           "to #{remaining} sellers on all four channels."
      puts 'Press Ctrl+C within 5 seconds to abort...'
      sleep(5)

      job = if send_at_time
              SendCatalogUploadBroadcastJob.set(wait_until: send_at_time).perform_later(dry_run: false)
            else
              SendCatalogUploadBroadcastJob.perform_later(dry_run: false)
            end

      puts "Broadcast job #{send_at_time ? 'scheduled' : 'enqueued'} " \
           "(job_id: #{job.job_id}) — per-seller sends queue on :broadcast individually."
    end
  end
end
