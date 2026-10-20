class OrganicFeaturedService
  SLOTS_PER_CATEGORY = 3
  FEATURED_DURATION = 7.days
  COOLDOWN_PERIOD = 14.days
  MIN_QUALITY_SCORE = 18.0

  def self.elect_featured_ads!(slots_per_category: SLOTS_PER_CATEGORY)
    new(slots_per_category: slots_per_category).elect!
  end

  def initialize(slots_per_category: SLOTS_PER_CATEGORY)
    @slots_per_category = slots_per_category
  end

  def elect!
    Rails.logger.info "[OrganicFeaturedService] Starting organic featured rotation (slots_per_cat=#{@slots_per_category})..."

    categories = Category.all
    newly_elected = []

    categories.each do |category|
      # Count how many ads are still actively in their 7-day featured cycle
      active_count = Ad.active
                       .where(category_id: category.id)
                       .where('featured_until > ?', Time.current)
                       .count

      needed_slots = @slots_per_category - active_count
      next if needed_slots <= 0

      candidates = fetch_top_candidates(category.id, limit: needed_slots)
      next if candidates.empty?

      candidates.each do |row|
        ad_id = row['id']
        score = row['calculated_score'].to_f.round(2)

        ad = Ad.find_by(id: ad_id)
        next unless ad

        ad.update_columns(
          featured_at: Time.current,
          featured_until: Time.current + FEATURED_DURATION,
          last_featured_at: Time.current,
          organic_quality_score: score
        )

        newly_elected << { id: ad.id, title: ad.title, category: category.name, score: score }
        Rails.logger.info "[OrganicFeaturedService] Featured Ad ##{ad.id} ('#{ad.title.to_s.slice(0, 30)}') in '#{category.name}' (score=#{score})"
      end
    end

    clear_featured_caches!

    summary = {
      newly_elected_count: newly_elected.size,
      total_active_featured: Ad.active.where('featured_until > ?', Time.current).count,
      newly_elected: newly_elected
    }

    Rails.logger.info "[OrganicFeaturedService] Completed. Total active featured ads: #{summary[:total_active_featured]}"
    summary
  end

  def fetch_top_candidates(category_id, limit: 3)
    cooldown_cutoff = Time.current - COOLDOWN_PERIOD

    sql = <<~SQL.squish
      SELECT
        ads.id,
        ads.title,
        ads.category_id,
        (
          /* 1. Image Quality (max 15 pts) */
          CASE
            WHEN ads.media LIKE '[%' AND length(ads.media) > 120 THEN 15.0
            WHEN ads.media LIKE '[%' AND length(ads.media) > 40 THEN 10.0
            ELSE 5.0
          END +
          /* 2. Description Richness (max 10 pts) */
          CASE
            WHEN length(COALESCE(ads.description, '')) >= 250 THEN 10.0
            WHEN length(COALESCE(ads.description, '')) >= 100 THEN 6.0
            ELSE 2.0
          END +
          /* 3. Structured Metadata (max 5 pts) */
          CASE WHEN ads.brand IS NOT NULL AND ads.brand NOT IN ('', 'Generic') THEN 3.0 ELSE 0.0 END +
          CASE WHEN ads.specifications IS NOT NULL AND ads.specifications::text NOT IN ('{}', 'null', '') THEN 2.0 ELSE 0.0 END +
          /* 4. Pricing Transparency (max 5 pts) */
          CASE
            WHEN ads.price > 0 AND (ads.specifications->>'pricing_unit') IS NOT NULL AND (ads.specifications->>'pricing_unit') != '' THEN 5.0
            WHEN ads.price > 0 THEN 3.0
            ELSE 1.0
          END +
          /* 5. Seller Trust & Verification (max 10 pts) */
          CASE WHEN sellers.document_verified = true THEN 6.0 ELSE 0.0 END +
          CASE WHEN sellers.carbon_code_id IS NOT NULL THEN 2.0 ELSE 0.0 END +
          CASE WHEN COALESCE(ad_stats.review_count, 0) > 0 AND ad_stats.avg_rating >= 4.0 THEN 2.0 ELSE 0.0 END +
          /* 6. High-Intent Engagement (max 40 pts) */
          LEAST(LN(COALESCE(ad_stats.reveal_details_7d, 0) + 1) * 6.0, 18.0) +
          LEAST(LN(COALESCE(ad_stats.click_count, 0) + 1) * 3.5, 12.0) +
          LEAST(LN(COALESCE(ad_stats.message_seller_7d, 0) + COALESCE(ad_stats.quote_request_7d, 0) + COALESCE(ad_stats.callback_request_7d, 0) + 1) * 4.0, 6.0) +
          LEAST(LN(COALESCE(ad_stats.wishlist_count, 0) + COALESCE(ad_stats.add_to_cart_7d, 0) + 1) * 2.0, 4.0) +
          /* 7. Upload Freshness (max 15 pts) */
          CASE
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '7 days' THEN 15.0
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '21 days' THEN 10.0
            WHEN ads.created_at >= CURRENT_DATE - INTERVAL '60 days' THEN 5.0
            ELSE 0.0
          END
        ) as calculated_score
      FROM ads
      INNER JOIN ad_stats ON ad_stats.ad_id = ads.id
      INNER JOIN sellers ON sellers.id = ads.seller_id
      WHERE ads.deleted = false
        AND ads.flagged = false
        AND sellers.blocked = false
        AND sellers.deleted = false
        AND sellers.flagged = false
        AND ads.media IS NOT NULL
        AND ads.media != ''
        AND ads.media != '[]'
        AND ads.category_id = #{ActiveRecord::Base.connection.quote(category_id)}
        /* Exclude ads currently active as featured */
        AND (ads.featured_until IS NULL OR ads.featured_until <= #{ActiveRecord::Base.connection.quote(Time.current)})
        /* Exclude ads currently in the 14-day anti-monopoly cooldown */
        AND (ads.last_featured_at IS NULL OR ads.last_featured_at < #{ActiveRecord::Base.connection.quote(cooldown_cutoff)})
        /* Minimum Quality/Content threshold */
        AND (
          CASE
            WHEN ads.media LIKE '[%' AND length(ads.media) > 120 THEN 15.0
            WHEN ads.media LIKE '[%' AND length(ads.media) > 40 THEN 10.0
            ELSE 5.0
          END +
          CASE
            WHEN length(COALESCE(ads.description, '')) >= 250 THEN 10.0
            WHEN length(COALESCE(ads.description, '')) >= 100 THEN 6.0
            ELSE 2.0
          END
        ) >= 11.0
      ORDER BY calculated_score DESC, ads.created_at DESC
      LIMIT #{limit.to_i}
    SQL

    ActiveRecord::Base.connection.execute(sql).to_a
  end

  def clear_featured_caches!
    # Invalidate buyer featured ads and offers caches
    Rails.cache.delete_matched("buyer_ads_featured*") rescue nil
    Rails.cache.delete_matched("buyer_offers_featured*") rescue nil
  end
end
