# frozen_string_literal: true

namespace :brand_kenya do
  desc 'Send the complete-profile email to Brand Kenya brands that are onboarded. ' \
       'DRY_RUN=true previews without sending; MARK_SENT=id1,id2 marks brands ' \
       'already emailed manually so they are skipped.'
  task notify_onboarded: :environment do
    outreach = BrandKenyaOutreach.new

    ENV.fetch('MARK_SENT', '').split(',').map(&:strip).compact_blank.each do |id|
      brand = SalesBrand.includes(:activities).find_by(id: id)
      if brand.nil?
        puts "MARK_SENT: no brand with id #{id}"
      elsif outreach.emailed?(brand)
        puts "MARK_SENT: #{brand.name} already marked"
      else
        outreach.mark_sent!(brand)
        puts "MARK_SENT: recorded for #{brand.name}"
      end
    end

    outreach.notify_onboarded(dry_run: ENV['DRY_RUN'] == 'true')
  end

  desc 'Cold-intro email to Brand Kenya directory brands with valid emails. ' \
       'Defaults to TEST MODE: sends samples to TEST_EMAIL (default ' \
       'kiruivictor097@gmail.com, TEST_COUNT=1) and marks nothing as sent. ' \
       'LIVE=true sends to real brand addresses; LIMIT=n caps the batch.'
  task cold_outreach: :environment do
    outreach = BrandKenyaOutreach.new

    if ENV['LIVE'] == 'true'
      outreach.cold_outreach(limit: ENV['LIMIT']&.to_i)
    else
      outreach.cold_outreach(
        test_email: ENV['TEST_EMAIL'].presence || 'kiruivictor097@gmail.com',
        test_count: (ENV['TEST_COUNT'] || 1).to_i
      )
    end
  end
end
