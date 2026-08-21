# frozen_string_literal: true

class ModerateAdJob < ApplicationJob
  queue_as :default

  # Evaluates an ad asynchronously using the multi-signal composite risk engine.
  # Operates in :shadow_mode (log-only) or :active_mode (auto-flagging).
  def perform(ad_id, mode: :active_mode)
    ad = Ad.find_by(id: ad_id)
    return unless ad

    result = ContentModeration::CompositeRiskEngine.evaluate_ad(ad)
    verdict = result[:verdict]
    score = result[:composite_score]
    reason = result[:primary_reason]

    Rails.logger.info "[ContentModeration] Ad #{ad.id} evaluated: Verdict=#{verdict}, Score=#{score}, Reason=#{reason}"

    if mode == :active_mode
      case verdict
      when :rejected
        ad.update(
          flagged: true,
          flag_notes: "Auto-Rejected [Score: #{score}]: #{reason}"
        )
        SellerMailer.ad_flagged(ad.seller, ad, ad.flag_notes).deliver_later if ad.seller
      when :held
        ad.update(
          flagged: true,
          flag_notes: "Held for Quality Review [Score: #{score}]: #{reason}"
        )
        SellerMailer.ad_flagged(ad.seller, ad, ad.flag_notes).deliver_later if ad.seller
      when :soft_flagged
        # Keep ad visible to buyers, but create a high-priority call queue / review item for sales/admin
        if defined?(CallQueue) && ad.seller
          CallQueue.create(
            seller: ad.seller,
            priority: 2,
            reasons: ["Listing soft-flagged for verification: #{ad.title} (Score: #{score})"].to_json,
            metadata: { ad_id: ad.id, score: score, reason: reason }
          )
        end
      when :auto_approved
        # If ad was previously flagged by auto-moderation and now passes after seller edits, restore it automatically!
        if ad.flagged? && ad.flag_notes.to_s.start_with?("Auto-Rejected", "Held for Quality Review")
          ad.update(flagged: false, flag_notes: nil)
        end
      end
    end

    result
  end
end
