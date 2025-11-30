#!/usr/bin/env ruby
# Test script for optimized deals API performance
# Run with: rails runner test_optimized_deals.rb

require 'benchmark'

puts "=== Testing Optimized Carbon Deals API ===\n"

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require_relative 'config/environment'

class OptimizedDealsTester
  include Benchmark

  def test_optimized_offers_query
    puts "Testing optimized offers query performance..."
    time = Benchmark.measure do
      # Simulate the optimized query from the controller
      where_conditions = ["offers.status IN ('active', 'scheduled')"]
      where_params = []

      where_conditions << "offers.end_time > ?"
      where_params << Time.current

      sql = <<-SQL
        SELECT
          offers.id,
          offers.name,
          offers.description,
          offers.offer_type,
          offers.discount_type,
          offers.discount_percentage,
          offers.fixed_discount_amount,
          offers.start_time,
          offers.end_time,
          offers.featured,
          offers.priority,
          offers.show_on_homepage,
          offers.target_categories,
          offers.minimum_order_amount,
          offers.banner_color,
          offers.badge_color,
          offers.icon_name,
          offers.badge_text,
          offers.cta_text,
          offers.view_count,
          offers.click_count,
          offers.conversion_count,
          offers.revenue_generated,
          sellers.id as seller_id,
          sellers.enterprise_name as seller_name,
          sellers.fullname as seller_fullname,
          tiers.id as seller_tier_id,
          tiers.name as seller_tier_name
        FROM offers
        INNER JOIN sellers ON sellers.id = offers.seller_id
        LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
        LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id
        WHERE #{where_conditions.join(' AND ')}
          AND sellers.blocked = false
          AND sellers.deleted = false
          AND sellers.flagged = false
        ORDER BY offers.priority DESC, offers.created_at DESC
        LIMIT ? OFFSET ?
      SQL

      query_params = where_params + [100, 0]

      offers_data = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql] + query_params)
      )

      # Get ads for offers
      if offers_data.any?
        offer_ids = offers_data.map { |row| row['id'] }

        ads_sql = <<-SQL
          SELECT
            offer_ads.offer_id,
            offer_ads.original_price,
            offer_ads.discounted_price,
            offer_ads.discount_percentage,
            ads.id,
            ads.title,
            ads.price,
            ads.media,
            ads.created_at,
            categories.name as category_name,
            subcategories.name as subcategory_name,
            ad_sellers.fullname as seller_name,
            ad_tiers.id as seller_tier_id,
            ad_tiers.name as seller_tier_name,
            COALESCE(review_stats.review_count, 0) as review_count,
            COALESCE(review_stats.avg_rating, 0.0) as avg_rating
          FROM offer_ads
          INNER JOIN ads ON ads.id = offer_ads.ad_id
          INNER JOIN categories ON categories.id = ads.category_id
          INNER JOIN subcategories ON subcategories.id = ads.subcategory_id
          INNER JOIN sellers ad_sellers ON ad_sellers.id = ads.seller_id
          LEFT JOIN seller_tiers ad_seller_tiers ON ad_sellers.id = ad_seller_tiers.seller_id
          LEFT JOIN tiers ad_tiers ON ad_seller_tiers.tier_id = ad_tiers.id
          LEFT JOIN (
            SELECT
              ad_id,
              COUNT(*) as review_count,
              AVG(rating) as avg_rating
            FROM reviews
            GROUP BY ad_id
          ) review_stats ON review_stats.ad_id = ads.id
          WHERE offer_ads.offer_id IN (#{offer_ids.map { '?' }.join(',')})
            AND ads.deleted = false
            AND ads.flagged = false
            AND ad_sellers.blocked = false
            AND ad_sellers.deleted = false
            AND ad_sellers.flagged = false
          ORDER BY offer_ads.offer_id, ads.created_at DESC
        SQL

        ads_data = ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.send(:sanitize_sql_array, [ads_sql] + offer_ids)
        )

        # Group and process data
        ads_by_offer = {}
        ads_data.each do |row|
          offer_id = row['offer_id']
          ads_by_offer[offer_id] ||= []
          ads_by_offer[offer_id] << row
        end

        offers = offers_data.map do |offer_row|
          offer_id = offer_row['id']
          ads = ads_by_offer[offer_id] || []

          {
            id: offer_id,
            name: offer_row['name'],
            ads: ads.map do |ad_row|
              {
                id: ad_row['id'],
                title: ad_row['title'],
                price: ad_row['price'],
                media: ad_row['media']
              }
            end
          }
        end
      end

      puts "  - Found #{offers_data.count} offers with ads"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def test_optimized_active_offers
    puts "Testing optimized active_offers query..."
    time = Benchmark.measure do
      sql = <<-SQL
        SELECT
          offers.id,
          offers.name,
          offers.description,
          offers.offer_type,
          offers.discount_type,
          offers.discount_percentage,
          offers.fixed_discount_amount,
          offers.start_time,
          offers.end_time,
          offers.featured,
          offers.priority,
          offers.banner_color,
          offers.badge_color,
          offers.icon_name,
          offers.badge_text,
          offers.cta_text,
          offers.view_count,
          offers.click_count,
          sellers.id as seller_id,
          sellers.enterprise_name as seller_name,
          sellers.fullname as seller_fullname,
          tiers.id as seller_tier_id,
          tiers.name as seller_tier_name,
          COUNT(offer_ads.id) as ads_count
        FROM offers
        INNER JOIN sellers ON sellers.id = offers.seller_id
        LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id
        LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id
        LEFT JOIN offer_ads ON offer_ads.offer_id = offers.id
        WHERE offers.status = 'active'
          AND offers.start_time <= ?
          AND offers.end_time >= ?
          AND offers.show_on_homepage = true
          AND offers.featured = true
          AND sellers.blocked = false
          AND sellers.deleted = false
          AND sellers.flagged = false
        GROUP BY offers.id, sellers.id, seller_tiers.id, tiers.id
        ORDER BY offers.priority DESC, offers.created_at DESC
        LIMIT 5
      SQL

      offers_data = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, Time.current, Time.current])
      )

      offers = offers_data.map do |row|
        {
          id: row['id'],
          name: row['name'],
          seller: {
            id: row['seller_id'],
            name: row['seller_name'] || row['seller_fullname']
          },
          ads_count: row['ads_count']
        }
      end

      puts "  - Found #{offers.size} active featured offers"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def run_tests
    puts "Running optimized deals tests...\n\n"

    results = {}

    puts "=" * 50
    results[:optimized_offers] = test_optimized_offers_query
    puts

    puts "=" * 50
    results[:optimized_active] = test_optimized_active_offers
    puts

    # Summary
    puts "=" * 60
    puts "OPTIMIZED DEALS PERFORMANCE RESULTS:"
    puts "=" * 60

    total_time = results.values.sum
    results.each do |component, time|
      percentage = ((time / total_time) * 100).round(1)
      puts "#{component.to_s.upcase}: #{time.round(4)}s (#{percentage}%)"
    end

    puts "\nTotal optimized deals time: #{total_time.round(4)}s (#{total_time * 1000}ms)"
    puts "Previous deals time was: 1.144s"

    improvement = ((1.144 - total_time) / 1.144 * 100).round(1)
    puts "Improvement: #{improvement}% faster"

    if total_time < 0.2
      puts "✅ EXCELLENT: Deals are now very fast!"
    elsif total_time < 0.5
      puts "✅ GOOD: Deals performance is acceptable"
    elsif total_time < 1.0
      puts "⚠️  ACCEPTABLE: Deals are reasonably fast"
    else
      puts "❌ SLOW: Deals still need more optimization"
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = OptimizedDealsTester.new
  tester.run_tests
end
