#!/usr/bin/env ruby
# Benchmark script for buyer_ads_index API performance analysis
# Run with: rails runner benchmark_buyer_ads.rb

require 'benchmark'

puts "=== Carbon Buyer Ads Index Performance Benchmark ===\n"

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require_relative 'config/environment'

class BuyerAdsBenchmark
  include Benchmark

  def initialize
    @controller = Buyer::AdsController.new
    @request = ActionDispatch::TestRequest.create
    @response = ActionDispatch::Response.new

    # Set up controller context
    @controller.request = @request
    @controller.response = @response

    # Set some default params using the proper method
    @controller.params = { 'per_page' => '24', 'page' => '1' }
  end

  def benchmark_balanced_ads
    puts "Testing get_balanced_ads method..."
    time = Benchmark.measure do
      result = @controller.send(:get_balanced_ads, 24)
      puts "  - Returned #{result[:ads].size} ads"
      puts "  - Subcategory counts: #{result[:subcategory_counts].size} categories"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_best_sellers
    puts "Testing calculate_best_sellers_fast method..."
    time = Benchmark.measure do
      result = @controller.send(:calculate_best_sellers_fast, 20)
      puts "  - Returned #{result.size} best sellers"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_regular_ads_query
    puts "Testing regular ads query (cached)..."
    time = Benchmark.measure do
      @controller.params = { 'per_page' => '24', 'page' => '1' }
      @controller.request.params = @controller.params

      # Simulate the cached query path
      cache_key = "buyer_ads_24_1__#{Time.current.to_i / 60}"
      @ads = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
        ads_query = Ad.active.with_valid_images
                     .joins(:seller, :category, :subcategory)
                     .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
                     .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
                     .where(sellers: { blocked: false, deleted: false, flagged: false })
                     .where(flagged: false)
                     .includes(:category, :subcategory, seller: { seller_tier: :tier })

        @controller.send(:get_randomized_ads, ads_query, 24).to_a
      end
      puts "  - Returned #{@ads.size} ads"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_serialization
    puts "Testing serialization performance..."
    # Get some sample ads first
    ads = Ad.active.with_valid_images
               .joins(:seller, :category, :subcategory)
               .joins('LEFT JOIN seller_tiers ON sellers.id = seller_tiers.seller_id')
               .joins('LEFT JOIN tiers ON seller_tiers.tier_id = tiers.id')
               .where(sellers: { blocked: false, deleted: false, flagged: false })
               .where(flagged: false)
               .includes(:category, :subcategory, seller: { seller_tier: :tier })
               .limit(24)
               .to_a

    puts "  - Serializing #{ads.size} ads..."
    time = Benchmark.measure do
      optimized_ads = ads.map do |ad|
        {
          id: ad.id,
          title: ad.title,
          price: ad.price,
          media: ad.media,
          created_at: ad.created_at,
          subcategory_id: ad.subcategory_id,
          category_id: ad.category_id,
          seller_id: ad.seller_id,
          seller_tier: ad.seller&.seller_tier&.tier&.id || 1,
          seller_tier_name: ad.seller&.seller_tier&.tier&.name || "Free",
          seller_name: ad.seller&.fullname,
          category_name: ad.category&.name,
          subcategory_name: ad.subcategory&.name
        }
      end
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_count_queries
    puts "Testing count queries..."
    times = {}

    # Balanced ads count
    times[:balanced_count] = Benchmark.measure do
      count = Ad.active.with_valid_images.joins(:seller)
             .where(sellers: { blocked: false, deleted: false, flagged: false })
             .where(flagged: false)
             .count
      puts "  - Balanced count: #{count} ads"
    end.real

    # Filtered count
    times[:filtered_count] = Benchmark.measure do
      count = Ad.active.with_valid_images.joins(:seller)
             .where(sellers: { blocked: false, deleted: false, flagged: false })
             .where(flagged: false)
             .count
      puts "  - Filtered count: #{count} ads"
    end.real

    puts "  - Count queries total: #{(times.values.sum * 1000).round(2)}ms"
    times.values.sum
  end

  def benchmark_full_api_call
    puts "Testing full API call (buyer_ads_index)..."
    time = Benchmark.measure do
      @controller.params = { 'per_page' => '24', 'page' => '1' }
      @controller.request.params = @controller.params
      @controller.index
    end
    puts "  - Full API call time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def run_benchmarks
    puts "Starting benchmarks...\n\n"

    results = {}

    puts "=" * 50
    results[:balanced_ads] = benchmark_balanced_ads
    puts

    puts "=" * 50
    results[:best_sellers] = benchmark_best_sellers
    puts

    puts "=" * 50
    results[:regular_query] = benchmark_regular_ads_query
    puts

    puts "=" * 50
    results[:serialization] = benchmark_serialization
    puts

    puts "=" * 50
    results[:counts] = benchmark_count_queries
    puts

    puts "=" * 50
    results[:full_api] = benchmark_full_api_call
    puts

    # Summary
    puts "=" * 60
    puts "PERFORMANCE SUMMARY:"
    puts "=" * 60

    total_time = results.values.sum
    results.each do |component, time|
      percentage = ((time / total_time) * 100).round(1)
      puts "#{component.to_s.upcase}: #{time.round(4)}s (#{percentage}%)"
    end

    puts "\nTotal estimated time: #{total_time.round(4)}s (#{total_time * 1000}ms)"
    puts "Actual API time was: 1.3226s"

    # Identify bottlenecks
    puts "\nPOTENTIAL BOTTLENECKS:"
    results.each do |component, time|
      if time > 0.1 # More than 100ms
        puts "⚠️  #{component.to_s.upcase}: #{time.round(4)}s - HIGH IMPACT"
      elsif time > 0.05 # More than 50ms
        puts "⚡ #{component.to_s.upcase}: #{time.round(4)}s - MEDIUM IMPACT"
      end
    end
  end
end

# Run the benchmarks
if __FILE__ == $0
  benchmark = BuyerAdsBenchmark.new
  benchmark.run_benchmarks
end
