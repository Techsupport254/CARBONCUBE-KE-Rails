
# Script to debug calculate_best_sellers_fast
require_relative '../config/environment'

def debug_best_sellers(limit)
    rotation_key = Time.current.to_i / 900
    cache_key = "best_sellers_dynamic_#{limit}_#{rotation_key}"
    
    puts "Cache Key: #{cache_key}"
    
    # Bypass cache for debugging
    sql = <<-SQL
        SELECT * FROM (
          SELECT
                       ads.id,
                       ads.title,
                       ads.price,
                       ads.media,
                       ads.created_at,
            ads.category_id,
            ads.subcategory_id,
            ads.seller_id,
                       sellers.fullname as seller_name,
                       categories.name as category_name,
                       subcategories.name as subcategory_name,
                       COALESCE(tiers.id, 1) as seller_tier_id,
                       COALESCE(tiers.name, 'Free') as seller_tier_name,

            -- Pre-calculated metrics
            COALESCE(wishlist_stats.wishlist_count, 0) as wishlist_count,
            COALESCE(review_stats.review_count, 0) as review_count,
            COALESCE(review_stats.avg_rating, 0.0) as avg_rating,
            COALESCE(click_stats.click_count, 0) as click_count,

            -- Calculated comprehensive score
            (
              (
                CASE
                  WHEN ads.created_at >= CURRENT_DATE - INTERVAL '7 days' THEN 8
                  WHEN ads.created_at >= CURRENT_DATE - INTERVAL '30 days' THEN 5
                  WHEN ads.created_at >= CURRENT_DATE - INTERVAL '90 days' THEN 3
                  WHEN ads.created_at >= CURRENT_DATE - INTERVAL '365 days' THEN 1
                  ELSE 0
                END * 0.25
              ) + (
                CASE COALESCE(tiers.id, 1)
                  WHEN 4 THEN 15
                  WHEN 3 THEN 8
                  WHEN 2 THEN 4
                  ELSE 0
                END * 0.15
              ) + (
                LN(COALESCE(wishlist_stats.wishlist_count, 0) + 1) * 20 * 0.25
              ) + (
                (
                  (COALESCE(review_stats.avg_rating, 0.0) / 5.0) * 30 +
                  LN(COALESCE(review_stats.review_count, 0) + 1) * 10
                ) * 0.20
              ) + (
                LN(COALESCE(click_stats.click_count, 0) + 1) * 15 * 0.15
              )
            ) as comprehensive_score

          FROM ads
          INNER JOIN sellers ON sellers.id = ads.seller_id
          INNER JOIN categories ON categories.id = ads.category_id
          INNER JOIN subcategories ON subcategories.id = ads.subcategory_id
          LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
          LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id

          LEFT JOIN (
            SELECT ad_id, COUNT(*) as wishlist_count
            FROM wish_lists
            GROUP BY ad_id
          ) wishlist_stats ON wishlist_stats.ad_id = ads.id

          LEFT JOIN (
            SELECT ad_id, COUNT(*) as review_count, AVG(rating) as avg_rating
            FROM reviews
            GROUP BY ad_id
          ) review_stats ON review_stats.ad_id = ads.id

          LEFT JOIN (
            SELECT ad_id, COUNT(*) as click_count
            FROM click_events
            WHERE event_type = 'Ad-Click'
            GROUP BY ad_id
          ) click_stats ON click_stats.ad_id = ads.id

          WHERE ads.deleted = false
            AND ads.flagged = false
            AND sellers.blocked = false
            AND sellers.deleted = false
            AND sellers.flagged = false
            AND ads.media IS NOT NULL
            AND ads.media != ''
            AND ads.media::text != '[]'
            AND (ads.media::jsonb -> 0) IS NOT NULL
        ) as sub
        ORDER BY (comprehensive_score * (1.0 + (RANDOM() * 0.4))) DESC
        LIMIT #{[limit * 3, 100].max}
    SQL
    
    results = ActiveRecord::Base.connection.execute(sql).to_a
    puts "Results count: #{results.size}"
    
    if results.any?
        puts "Sample result: #{results.first['title']} - Score: #{results.first['comprehensive_score']}"
    else
        puts "No ads found matching criteria."
        # Debug why
        puts "Total active ads: #{Ad.active.count}"
        puts "Ads with media: #{Ad.active.where.not(media: [nil, '', '[]']).count}"
    end
end

debug_best_sellers(18)
