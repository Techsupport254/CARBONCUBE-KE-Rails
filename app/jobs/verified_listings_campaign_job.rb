# Fans out the "verified listings get priority" campaign per active seller,
# staggered over a send window — same pattern as BlackFriday2026CampaignJob.
#
# Excludes BEFORE scheduling:
#   1. Already verified sellers:
#      - sellers.field_verified_at present
#        (document_verified flag is auto-set on signup — excluded signal)
#      - any seller_documents.document_verified = true
#      - seller_verifications with outcome 'verified' or 'corrected'
#   2. Sellers who already engaged/accepted verification in messages/follow-ups:
#      - any seller_verifications row whose outcome is NOT 'unreachable'/'not_found'
#        (a sales rep created a verification for them — they engaged)
#      - seller_follow_ups with status 'open' (agent actively working them)
#      ('unreachable'/'not_found' outcomes mean outreach failed — they are
#       still sent the email and counted separately in the report)
#
# DRY RUN (default — reports only, sends nothing):
#   VerifiedListingsCampaignJob.perform_later
#   VerifiedListingsCampaignJob.perform_now
#
# SEND (schedules per-seller deliveries):
#   VerifiedListingsCampaignJob.new.perform(false)
#   VerifiedListingsCampaignJob.perform_later(false)
#
require "set"

class VerifiedListingsCampaignJob < ApplicationJob
  queue_as :broadcast

  EMAIL_TYPE = 'verified_listings_priority'.freeze
  CHANNELS = { email: true, whatsapp: true }.freeze
  SEND_WINDOW_MINUTES = (ENV['VERIFIED_LISTINGS_WINDOW_MINUTES'] || 240).to_i

  # Outcomes meaning the seller never engaged — still safe to email.
  FAILED_OUTREACH = %w[unreachable not_found].freeze

  # Sellers who accepted verification in WhatsApp messages but are not yet
  # verified — manually confirmed from the sales team's chats:
  # Kilakitulaptops, Mugo kenol furniture, Gichane Carpet leasing,
  # Comrade Technologies, BarazaTech, Pst barasa
  MANUAL_EXCLUSION_IDS = %w[
    0d368fb1-b1a5-4539-a03e-c4610aaa15ed
    50d515c5-3bc7-4d39-a60f-5d9bee6b1c36
    25800436-d1f4-4070-9f9e-3dfd1176e780
    ef23819e-cc29-4426-b680-f928ede8af8b
    1ae958fa-f80d-45d2-8e83-b5e6906958fd
    9514f60d-972b-4bfd-888a-777ca2c889e7
  ].freeze
  # Name patterns for shops whose IDs weren't resolvable at write time.
  MANUAL_EXCLUSION_NAMES = %w[rinawa].freeze

  def perform(dry_run = true)
    sellers = Seller.where(deleted: [false, nil], blocked: [false, nil])
                    .where.not(email: [nil, ''])
                    .order(:id)

    # --- Exclusion sets (queried once) -----------------------------------
    seller_ids = sellers.pluck(:id)

    # NOTE: sellers.document_verified is auto-set for all 2025/2026 signups
    # (auto_verify_document_for_2025_and_2026_sellers) — NOT a real verification
    # signal, so it is intentionally not an exclusion.
    field_verified = sellers.where.not(field_verified_at: nil).pluck(:id).to_set
    doc_verified = SellerDocument.where(seller_id: seller_ids, document_verified: true)
                                 .pluck(:seller_id).to_set
    verification_success = SellerVerification.where(seller_id: seller_ids)
                                             .successful
                                             .pluck(:seller_id).to_set

    # Engaged/accepted — any verification record that isn't a failed outreach
    verification_engaged = SellerVerification.where(seller_id: seller_ids)
                                             .where.not(outcome: FAILED_OUTREACH)
                                             .pluck(:seller_id).to_set
    # Open follow-ups = an agent is actively working this seller
    # (verification call/WhatsApp/visit accepted or in progress)
    follow_up_engaged = SellerFollowUp.where(seller_id: seller_ids)
                                      .where(status: "open")
                                      .pluck(:seller_id).to_set

    # Failed outreach — reported separately, NOT excluded
    verification_failed = SellerVerification.where(seller_id: seller_ids)
                                            .where(outcome: FAILED_OUTREACH)
                                            .pluck(:seller_id).to_set

    manual_excluded = sellers.where(
      "id = ANY(ARRAY[?]::uuid[]) OR enterprise_name ILIKE ANY(ARRAY[?]) OR fullname ILIKE ANY(ARRAY[?])",
      MANUAL_EXCLUSION_IDS,
      MANUAL_EXCLUSION_NAMES.map { |n| "%#{n}%" },
      MANUAL_EXCLUSION_NAMES.map { |n| "%#{n}%" }
    ).pluck(:id).to_set

    excluded_verified = field_verified | doc_verified | verification_success
    excluded_engaged = (verification_engaged | follow_up_engaged | manual_excluded) - excluded_verified

    sendable_ids = seller_ids - excluded_verified.to_a - excluded_engaged.to_a

    # --- Report -----------------------------------------------------------
    Rails.logger.info <<~REPORT
      VerifiedListingsCampaignJob: #{dry_run ? 'DRY RUN' : 'SEND'} report
        active sellers (emailable): #{sellers.count}
        excluded — already verified:
          field_verified_at set:     #{field_verified.size}
          verified documents:        #{doc_verified.size}
          successful verifications:  #{verification_success.size}
          (union):                   #{excluded_verified.size}
        excluded — engaged/accepted:
          verification records:      #{verification_engaged.size}
          open follow-ups:           #{follow_up_engaged.size}
          manual (whatsapp accept):  #{manual_excluded.size}
          (union, minus verified):   #{excluded_engaged.size}
        still sendable:              #{sendable_ids.size}
        (failed outreach — included in sendable): #{verification_failed.size}
    REPORT

    if dry_run
      sendable = sellers.where(id: sendable_ids).pluck(:id, :email)
      Rails.logger.info "VerifiedListingsCampaignJob: sendable list — #{sendable.map { |id, e| "#{id}:#{e}" }.join(', ')}"
      Rails.logger.info 'VerifiedListingsCampaignJob: dry run complete — nothing sent'
      return
    end

    unless Rails.env.production?
      Rails.logger.info 'VerifiedListingsCampaignJob: skipping send outside production'
      return
    end

    scheduled = 0
    sellers.where(id: sendable_ids).find_each do |seller|
      offset = (SEND_WINDOW_MINUTES.to_f * rand).minutes
      SendSellerCommunicationJob
        .set(wait: offset)
        .perform_later(seller.id, EMAIL_TYPE, CHANNELS)
      scheduled += 1
    rescue => e
      Rails.logger.error "VerifiedListingsCampaignJob: failed to schedule seller #{seller.id}: #{e.message}"
    end

    Rails.logger.info "VerifiedListingsCampaignJob: scheduled #{scheduled}/#{sendable_ids.size} emails over ~#{SEND_WINDOW_MINUTES}min"
  end
end
