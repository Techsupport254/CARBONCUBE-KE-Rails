# frozen_string_literal: true

module ContentModeration
  class CompositeRiskEngine
    # Thresholds for enterprise action policy
    THRESHOLDS = {
      auto_approved_max: 35,
      soft_flagged_max: 65,
      held_max: 84
    }.freeze

    # Evaluates an Ad or content payload against all multi-signal dimensions.
    # Returns comprehensive audit metadata, composite score (0-100), and final action verdict.
    def self.evaluate_ad(ad_record)
      title = ad_record.title.to_s
      description = ad_record.description.to_s
      category_name = ad_record.category&.name
      price = ad_record.price
      seller = ad_record.seller

      media_urls = if ad_record.media.present?
                     begin
                       parsed = ad_record.media.is_a?(String) ? JSON.parse(ad_record.media) : ad_record.media
                       Array(parsed).compact.map(&:to_s).compact_blank
                     rescue
                       [ad_record.media.to_s]
                     end
                   else
                     []
                   end

      evaluate_content(
        title: title,
        description: description,
        category_name: category_name,
        price: price,
        seller: seller,
        media_urls: media_urls
      )
    end

    def self.evaluate_content(title:, description:, category_name: nil, price: nil, seller: nil, media_urls: [])
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # 1. Evaluate Seller Trust Score (0 - 100)
      trust_data = SellerTrustScorer.score(seller)
      trust_score = trust_data[:trust_score]

      # 2. Evaluate Deterministic Heuristic Rules (0 - 100)
      heuristic_data = HeuristicRuleEvaluator.evaluate(title, description, { category: category_name, price: price })
      heuristic_risk = heuristic_data[:risk_score]

      # 3. Evaluate AI / NLP Contextual Model (0 - 100)
      nlp_data = NlpSafetyService.evaluate(title, description, category_name, price)
      nlp_risk = nlp_data[:risk_score]

      # 4. Evaluate Vision / Media Safety (0 - 100)
      vision_data = if media_urls.present?
                      VisionSafetyService.evaluate_images(media_urls, title)
                    else
                      { is_nsfw: false, nsfw_score: 0, reason: 'No media' }
                    end
      image_risk = vision_data[:nsfw_score]

      # 5. Composite Risk Calculation
      composite_score, primary_category, primary_reason = calculate_composite(
        trust_score: trust_score,
        heuristic_data: heuristic_data,
        nlp_data: nlp_data,
        vision_data: vision_data,
        image_risk: image_risk
      )

      # 6. Assign Verdict
      verdict = determine_verdict(composite_score, heuristic_data[:severity], is_nsfw: vision_data[:is_nsfw])

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

      {
        composite_score: composite_score,
        verdict: verdict,
        primary_category: primary_category,
        primary_reason: primary_reason,
        latency_ms: duration_ms,
        signals: {
          seller_trust: trust_data,
          heuristics: heuristic_data,
          nlp_ai: nlp_data,
          vision: vision_data,
          media_risk: image_risk
        }
      }
    end

    def self.calculate_composite(trust_score:, heuristic_data:, nlp_data:, vision_data:, image_risk:)
      heuristic_risk = heuristic_data[:risk_score]
      nlp_risk = nlp_data[:risk_score]
      is_critical_hazard = heuristic_data[:severity] == :critical

      if is_critical_hazard && heuristic_risk >= 90
        composite = heuristic_risk
        category = heuristic_data[:category]
        reason = heuristic_data[:reason]
      elsif vision_data[:is_nsfw] && image_risk >= 50
        # Severe NSFW image violation
        composite = [image_risk + 20, 95].min
        category = 'NSFW_MEDIA'
        reason = "Inappropriate / NSFW image detected: #{vision_data[:reason]}"
      else
        # Weighted raw content risk: 45% NLP Context, 35% Heuristics, 20% Media
        raw_content_risk = (0.45 * nlp_risk) + (0.35 * heuristic_risk) + (0.20 * image_risk)

        # Trust discount: high seller trust can dampen raw risk by up to 60%
        trust_discount = (trust_score / 100.0) * 0.60
        adjusted_risk = raw_content_risk * (1.0 - trust_discount)

        composite = adjusted_risk.round.clamp(0, 100)

        if image_risk > nlp_risk && image_risk > heuristic_risk
          category = 'MEDIA_CONCERN'
          reason = vision_data[:reason]
        elsif nlp_risk > heuristic_risk
          category = nlp_data[:category]
          reason = nlp_data[:reason]
        elsif heuristic_risk.positive?
          category = heuristic_data[:category]
          reason = heuristic_data[:reason]
        else
          category = 'NONE'
          reason = 'Passed all safety checks'
        end
      end

      [composite, category, reason]
    end

    def self.determine_verdict(score, severity, is_nsfw: false)
      return :rejected if severity == :critical && score >= 85
      return :rejected if is_nsfw && score >= 80

      if score <= THRESHOLDS[:auto_approved_max]
        :auto_approved
      elsif score <= THRESHOLDS[:soft_flagged_max]
        :soft_flagged
      elsif score <= THRESHOLDS[:held_max]
        :held
      else
        :rejected
      end
    end

    private_class_method :calculate_composite, :determine_verdict
  end
end
