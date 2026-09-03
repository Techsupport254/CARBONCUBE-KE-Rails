class CreateAdStatsMaterializedView < ActiveRecord::Migration[7.1]
  def up
    execute(<<~SQL.squish)
      CREATE MATERIALIZED VIEW ad_stats AS
      SELECT
        ads.id AS ad_id,
        conv_stats.conversations_7d,
        conv_stats.conversations_30d,
        conv_stats.conversations_90d,
        cart_stats.add_to_cart_7d,
        cart_stats.add_to_cart_30d,
        click_stats.click_count,
        click_stats.message_seller_7d,
        click_stats.make_offer_7d,
        click_stats.callback_request_7d,
        click_stats.quote_request_7d,
        click_stats.reveal_details_7d,
        click_stats.share_ad_7d,
        wishlist_stats.wishlist_count,
        review_stats.review_count,
        review_stats.avg_rating
      FROM ads
      LEFT JOIN (
        SELECT
          ad_id,
          COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as conversations_7d,
          COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '30 days') as conversations_30d,
          COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '90 days') as conversations_90d
        FROM conversations
        WHERE ad_id IS NOT NULL
          AND buyer_id IS NOT NULL
          AND created_at >= CURRENT_DATE - INTERVAL '90 days'
        GROUP BY ad_id
      ) conv_stats ON conv_stats.ad_id = ads.id
      LEFT JOIN (
        SELECT
          ad_id,
          COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as add_to_cart_7d,
          COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '30 days') as add_to_cart_30d
        FROM cart_items
        WHERE created_at >= CURRENT_DATE - INTERVAL '90 days'
        GROUP BY ad_id
      ) cart_stats ON cart_stats.ad_id = ads.id
      LEFT JOIN (
        SELECT
          ce.ad_id,
          COUNT(*) FILTER (WHERE ce.event_type = 'Ad-Click' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as click_count,
          COUNT(*) FILTER (WHERE ce.event_type = 'Message-Seller' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as message_seller_7d,
          COUNT(*) FILTER (WHERE ce.event_type = 'Make-Offer' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as make_offer_7d,
          COUNT(*) FILTER (WHERE ce.event_type = 'Callback-Request' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as callback_request_7d,
          COUNT(*) FILTER (WHERE ce.event_type = 'Quote-Request' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as quote_request_7d,
          COUNT(*) FILTER (WHERE ce.event_type = 'Reveal-Seller-Details' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as reveal_details_7d,
          COUNT(*) FILTER (WHERE ce.event_type = 'Share-Ad' AND ce.created_at >= CURRENT_DATE - INTERVAL '7 days') as share_ad_7d
        FROM click_events ce
        INNER JOIN ads a ON a.id = ce.ad_id
        WHERE ce.created_at >= CURRENT_DATE - INTERVAL '90 days'
          AND (ce.seller_id IS NULL OR ce.seller_id != a.seller_id)
        GROUP BY ce.ad_id
      ) click_stats ON click_stats.ad_id = ads.id
      LEFT JOIN (
        SELECT ad_id, COUNT(*) as wishlist_count
        FROM wish_lists
        WHERE created_at >= CURRENT_DATE - INTERVAL '90 days'
        GROUP BY ad_id
      ) wishlist_stats ON wishlist_stats.ad_id = ads.id
      LEFT JOIN (
        SELECT ad_id, COUNT(*) as review_count, AVG(rating) as avg_rating
        FROM reviews
        GROUP BY ad_id
      ) review_stats ON review_stats.ad_id = ads.id
      WHERE ads.deleted = false
        AND ads.flagged = false
        AND ads.media IS NOT NULL
        AND ads.media != ''
        AND ads.media::text != '[]'
        AND (ads.media::jsonb -> 0) IS NOT NULL
    SQL

    execute 'CREATE UNIQUE INDEX index_ad_stats_on_ad_id ON ad_stats (ad_id)'
  end

  def down
    execute 'DROP MATERIALIZED VIEW IF EXISTS ad_stats'
  end
end
