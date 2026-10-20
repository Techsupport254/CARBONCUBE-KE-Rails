class OrganicFeaturedService
  SLOTS_PER_CATEGORY = 5
  FEATURED_DURATION = 3.days
  COOLDOWN_PERIOD = 7.days
  MIN_QUALITY_SCORE = 18.0

  def self.elect_featured_ads!(slots_per_category: SLOTS_PER_CATEGORY)
    new(slots_per_category: slots_per_category).elect!
  end

  def initialize(slots_per_category: SLOTS_PER_CATEGORY)
    @slots_per_category = slots_per_category
  end

  def elect!
    Rails.logger.info "[OrganicFeaturedService] Starting organic featured rotation (slots_per_cat=#{@slots_per_category}, duration=#{FEATURED_DURATION.inspect})..."

    categories = Category.all
    newly_elected = []

    # 1. Track sellers who currently have an active featured ad (strictly 1 ad per seller platform-wide)
    currently_active_seller_ids = Ad.active
                                    .where('featured_until > ?', Time.current)
                                    .pluck(:seller_id)
                                    .to_set

    # 2. Track sellers who had an ad featured recently within the cooldown period
    cooldown_cutoff = Time.current - COOLDOWN_PERIOD
    cooldown_seller_ids = Ad.where('last_featured_at >= ?', cooldown_cutoff)
                            .pluck(:seller_id)
                            .to_set - currently_active_seller_ids

    # 3. Track sellers who have ever had an ad featured (for discovery bonus)
    ever_featured_seller_ids = Ad.where.not(last_featured_at: nil)
                                 .pluck(:seller_id)
                                 .to_set

    chosen_seller_ids = currently_active_seller_ids.dup

    categories.each do |category|
      # Count how many ads are still actively featured in this category
      active_count = Ad.active
                       .where(category_id: category.id)
                       .where('featured_until > ?', Time.current)
                       .count

      needed_slots = @slots_per_category - active_count
      next if needed_slots <= 0

      # Priority 1: Pick candidates excluding both active sellers AND sellers in cooldown
      primary_exclusions = (chosen_seller_ids + cooldown_seller_ids).to_a
      candidates = fetch_top_candidates(
        category.id,
        limit: needed_slots * 5,
        excluded_seller_ids: primary_exclusions,
        ever_featured_seller_ids: ever_featured_seller_ids.to_a
      )

      # Priority 2: Fallback if not enough candidates outside cooldown (e.g. small categories)
      if candidates.size < needed_slots
        fallback_candidates = fetch_top_candidates(
          category.id,
          limit: needed_slots * 5,
          excluded_seller_ids: chosen_seller_ids.to_a,
          ever_featured_seller_ids: ever_featured_seller_ids.to_a
        )
        existing_candidate_ids = candidates.map { |c| c['id'] }.to_set
        fallback_candidates.each do |fc|
          candidates << fc unless existing_candidate_ids.include?(fc['id'])
        end
      end

      next if candidates.empty?

      category_elected_count = 0
      candidates.each do |row|
        break if category_elected_count >= needed_slots

        seller_id = row['seller_id']
        next if chosen_seller_ids.include?(seller_id)

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

        chosen_seller_ids.add(seller_id)
        category_elected_count += 1
        newly_elected << { id: ad.id, title: ad.title, category: category.name, seller_id: seller_id, score: score }
        Rails.logger.info "[OrganicFeaturedService] Featured Ad ##{ad.id} ('#{ad.title.to_s.slice(0, 30)}') for seller #{seller_id} in '#{category.name}' (score=#{score})"
      end
    end

    clear_featured_caches!

    summary = {
      newly_elected_count: newly_elected.size,
      total_active_featured: Ad.active.where('featured_until > ?', Time.current).count,
      unique_featured_sellers: chosen_seller_ids.size,
      newly_elected: newly_elected
    }

    Rails.logger.info "[OrganicFeaturedService] Completed. Total active featured ads: #{summary[:total_active_featured]} across #{summary[:unique_featured_sellers]} unique sellers"
    summary
  end

  def fetch_top_candidates(category_id, limit: 15, excluded_seller_ids: [], ever_featured_seller_ids: [])
    cooldown_cutoff = Time.current - COOLDOWN_PERIOD
    seller_exclusion_sql = if excluded_seller_ids.present?
      "AND ads.seller_id NOT IN (#{excluded_seller_ids.map { |id| ActiveRecord::Base.connection.quote(id) }.join(',')})"
    else
      ""
    end

    # Discovery Bonus (+8.0 pts) for sellers who have never had any listing featured yet
    discovery_bonus_sql = if ever_featured_seller_ids.present?
      "CASE WHEN ads.seller_id NOT IN (#{ever_featured_seller_ids.map { |id| ActiveRecord::Base.connection.quote(id) }.join(',')}) THEN 8.0 ELSE 0.0 END"
    else
      "8.0"
    end

    sql = <<~SQL.squish
      SELECT
        ads.id,
        ads.title,
        ads.category_id,
        ads.seller_id,
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
          END +
          /* 8. Seller Discovery Bonus (max 8 pts) - promotes sellers who have not been featured yet */
          #{discovery_bonus_sql}
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
        #{seller_exclusion_sql}
        /* Exclude ads currently active as featured */
        AND (ads.featured_until IS NULL OR ads.featured_until <= #{ActiveRecord::Base.connection.quote(Time.current)})
        /* Exclude ads currently in the anti-monopoly cooldown */
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
