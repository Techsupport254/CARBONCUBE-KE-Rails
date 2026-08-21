# frozen_string_literal: true

module ContentModeration
  class SellerTrustScorer
    # Calculates a composite trust score (0 - 100) for a seller.
    # Higher trust scores significantly dampen false-positive risk for verified merchants.
    def self.score(seller)
      return default_anonymous_score unless seller

      trust_points = 0.0
      breakdown = {}

      # 1. KYC / Document Verification (Max 35 points)
      verified_docs_count = seller.seller_documents.respond_to?(:verified) ? seller.seller_documents.verified.count : 0
      if verified_docs_count.positive?
        doc_points = [verified_docs_count * 20.0, 35.0].min
        trust_points += doc_points
        breakdown[:kyc_verified] = doc_points
      elsif seller.business_registration_number.present?
        trust_points += 15.0
        breakdown[:business_reg_present] = 15.0
      end

      # 2. Paid / Verified Tier Status (Max 25 points)
      tier_name = seller.tier&.name || seller.seller_tier&.tier&.name
      case tier_name&.downcase
      when 'gold', 'enterprise', 'platinum'
        trust_points += 25.0
        breakdown[:tier_tier] = 25.0
      when 'silver', 'standard', 'pro'
        trust_points += 18.0
        breakdown[:tier_tier] = 18.0
      when 'bronze', 'basic'
        trust_points += 10.0
        breakdown[:tier_tier] = 10.0
      else
        # Check if seller has successful payment transactions
        if seller.payment_transactions.exists?(status: 'completed')
          trust_points += 15.0
          breakdown[:paid_history] = 15.0
        end
      end

      # 3. Account Age & Longevity (Max 20 points)
      account_age_days = ((Time.current - seller.created_at) / 1.day).to_i
      age_points = if account_age_days > 180
                     20.0
                   elsif account_age_days > 60
                     15.0
                   elsif account_age_days > 14
                     8.0
                   elsif account_age_days > 2
                     3.0
                   else
                     0.0
                   end
      trust_points += age_points
      breakdown[:account_age_days] = account_age_days
      breakdown[:account_age_points] = age_points

      # 4. Historical Track Record (Max 15 points)
      total_ads = seller.ads.count
      flagged_ads = seller.ads.where(flagged: true).count
      if total_ads >= 5
        clean_ratio = (total_ads - flagged_ads).to_f / total_ads
        if clean_ratio >= 0.95
          trust_points += 15.0
          breakdown[:clean_ad_history] = 15.0
        elsif clean_ratio >= 0.8
          trust_points += 8.0
          breakdown[:clean_ad_history] = 8.0
        end
      end

      # 5. Customer Reviews & Ratings (Max 10 points)
      mean_rating = seller.calculate_mean_rating
      reviews_count = seller.reviews_received.count
      if reviews_count >= 3
        if mean_rating >= 4.0
          trust_points += 10.0
          breakdown[:reviews_bonus] = 10.0
        elsif mean_rating >= 3.0
          trust_points += 5.0
          breakdown[:reviews_bonus] = 5.0
        end
      end

      # 6. Branch & Physical Location Precision (Max 5 points)
      if seller.branches.exists?(location_precision: 'exact') || seller.branches.where.not(latitude: nil).exists?
        trust_points += 5.0
        breakdown[:verified_location] = 5.0
      end

      # Penalties for blocked status or high flag rate
      if seller.blocked?
        trust_points = 0.0
        breakdown[:penalty_blocked] = -100
      elsif flagged_ads > 3 && flagged_ads > (total_ads * 0.3)
        trust_points = [trust_points - 30.0, 0.0].max
        breakdown[:penalty_high_flags] = -30
      end

      final_score = [trust_points.round(1), 100.0].min
      {
        trust_score: final_score,
        trust_level: classify_trust_level(final_score),
        breakdown: breakdown
      }
    end

    def self.classify_trust_level(score)
      if score >= 70
        :highly_trusted
      elsif score >= 40
        :trusted
      elsif score >= 20
        :neutral
      else
        :unverified_new
      end
    end

    def self.default_anonymous_score
      {
        trust_score: 15.0,
        trust_level: :unverified_new,
        breakdown: { anonymous: 15.0 }
      }
    end
  end
end
