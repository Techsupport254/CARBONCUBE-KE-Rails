# frozen_string_literal: true

# Sends Brand Kenya campaign emails to sales_brands directory entries and
# records each send as an `email` activity on the brand's timeline — visible
# in the sales dashboard and makes repeat runs idempotent.
#
# Two flows share the same dedup/skip rules:
# - notify_onboarded: complete-profile nudge once a brand reaches onboarded
# - cold_outreach: first-touch intro to directory brands with valid emails
class BrandKenyaOutreach
  ONBOARDED_NOTE = 'Sent Brand Kenya complete-profile email'
  COLD_NOTE = 'Sent Brand Kenya intro email'
  ACTOR_NAME = 'Automated email'

  # Any timeline email whose notes mention the campaign counts as sent —
  # covers our markers and sends reps logged by hand.
  EMAILED_NOTES = /complete.?profile|brand kenya/i

  Result = Struct.new(:sent, :failed, :skipped)

  def initialize(out: $stdout)
    @out = out
  end

  # Complete-profile nudge for brands that reached onboarded status.
  def notify_onboarded(dry_run: false)
    brands = SalesBrand.where(status: :onboarded).includes(:seller, :partner, :activities)
    log "Scanning #{brands.count} onboarded Brand Kenya brands#{' (DRY RUN)' if dry_run}..."
    result = new_result

    brands.find_each do |brand|
      next skip(result, :already_emailed) if emailed?(brand)

      recipient = recipient_for(brand)
      next skip(result, :no_recipient, brand) unless valid_email?(recipient)

      missing = BrandKenyaMailer.missing_items_for(brand)
      next skip(result, :profile_complete) if missing.empty?

      if dry_run
        result.sent += 1
        log "  WOULD SEND #{brand.name} <#{recipient}> — missing: #{missing.map { |i| i[:label] }.join('; ')}"
        next
      end

      send_and_record(brand, BrandKenyaMailer.complete_profile(brand), ONBOARDED_NOTE, result)
      sleep 1
    end

    summarize(result, dry_run ? 'would send' : 'sent')
    result
  end

  # First-touch intro for directory brands not yet onboarded. The mailer
  # picks copy/CTA by registration state: unregistered brands get a
  # claim-your-listing pitch, registered ones a finish-your-profile nudge.
  # test_email redirects every send to a review inbox — in that mode nothing
  # is marked as sent, at most test_count samples go out, and registered /
  # unregistered brands are interleaved so a couple of samples covers both
  # variants. Without it the emails go to real brand addresses (live mode).
  def cold_outreach(test_email: nil, test_count: 1, limit: nil)
    test_mode = test_email.present?
    scope = SalesBrand.where.not(status: %i[onboarded not_interested])
                      .includes(:seller, :partner, :activities)
    log "Scanning #{scope.count} Brand Kenya brands for cold outreach " \
        "(#{test_mode ? "TEST MODE → #{test_email}" : 'LIVE'})..."
    result = new_result

    pool = test_mode ? interleave_by_registration(scope) : scope.find_each
    pool.each do |brand|
      break if limit && result.sent >= limit
      break if test_mode && result.sent >= test_count
      next skip(result, :already_emailed) if emailed?(brand)

      recipient = recipient_for(brand)
      next skip(result, :no_recipient, brand) unless valid_email?(recipient)

      mail = BrandKenyaMailer.cold_outreach(brand, to: test_mode ? test_email : nil)
      variant = brand.seller_id.present? ? 'registered' : 'unregistered'
      send_and_record(brand, mail, test_mode ? nil : COLD_NOTE, result, detail: variant)
      sleep 1 unless test_mode
    end

    summarize(result, test_mode ? 'test-sent' : 'sent')
    result
  end

  # Record a send on the brand's timeline — also used to mark brands already
  # emailed by hand so they are skipped on subsequent runs.
  def mark_sent!(brand, note = ONBOARDED_NOTE)
    brand.activities.create!(
      activity_type: 'email',
      actor_name: ACTOR_NAME,
      occurred_at: Time.current,
      notes: note
    )
  end

  def emailed?(brand)
    brand.activities.any? do |a|
      a.activity_type == 'email' && a.notes.to_s.match?(EMAILED_NOTES)
    end
  end

  private

  def recipient_for(brand)
    brand.email.presence || brand.seller&.email
  end

  def valid_email?(address)
    address.to_s.match?(URI::MailTo::EMAIL_REGEXP)
  end

  # Alternate unregistered and registered brands so small test batches see
  # both email variants. zip pads the shorter side with nil, compacted away.
  def interleave_by_registration(scope)
    registered, unregistered = scope.to_a.partition { |b| b.seller_id.present? }
    unregistered.zip(registered).flatten.compact
  end

  def send_and_record(brand, mail, note, result, detail: nil)
    raise 'mailer returned no message' if mail.blank?

    mail.deliver_now
    mark_sent!(brand, note) if note
    result.sent += 1
    log "  SENT #{brand.name} <#{mail.to&.first}>#{" [#{detail}]" if detail}"
  rescue StandardError => e
    result.failed += 1
    log "  FAILED #{brand.name}: #{e.message}"
  end

  def new_result
    Result.new(0, 0, Hash.new(0))
  end

  def skip(result, reason, brand = nil)
    result.skipped[reason] += 1
    log "  SKIP #{brand.name}: no valid email" if brand && reason == :no_recipient
    nil
  end

  def summarize(result, verb)
    log "Done: #{result.sent} #{verb}, #{result.failed} failed, " \
        "#{result.skipped[:already_emailed]} already emailed, " \
        "#{result.skipped[:no_recipient]} no valid email, " \
        "#{result.skipped[:profile_complete]} profile already complete"
  end

  def log(message)
    @out << "#{message}\n"
  end
end
