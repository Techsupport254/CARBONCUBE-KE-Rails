#!/usr/bin/env ruby
# Benchmark script for deals API performance analysis
# Run with: rails runner benchmark_deals.rb

require 'benchmark'

puts "=== Carbon Deals API Performance Benchmark ===\n"

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require_relative 'config/environment'

class DealsBenchmark
  include Benchmark

  def initialize
    @controller = Buyer::OffersController.new
    @request = ActionDispatch::TestRequest.create
    @response = ActionDispatch::Response.new

    # Set up controller context
    @controller.request = @request
    @controller.response = @response
  end

  def benchmark_offers_query
    puts "Testing offers query performance..."
    time = Benchmark.measure do
      offers = Offer.where(status: ['active', 'scheduled'])
                   .where('end_time > ?', Time.current)
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .by_priority
                   .includes(:seller, :offer_ads, ads: [:category, :subcategory, :reviews, seller: :seller_tier])
                   .limit(100)

      offers_count = offers.size
      total_ads = offers.sum { |o| o.ads.size }

      puts "  - Found #{offers_count} offers with #{total_ads} total ads"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_active_offers_query
    puts "Testing active_offers query..."
    time = Benchmark.measure do
      offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .homepage_visible
                   .featured
                   .by_priority
                   .limit(5)

      offers_count = offers.size
      puts "  - Found #{offers_count} active featured offers"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_featured_offers_query
    puts "Testing featured_offers query..."
    time = Benchmark.measure do
      offers = Offer.active_now
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .featured
                   .by_priority
                   .limit(10)

      offers_count = offers.size
      puts "  - Found #{offers_count} featured offers"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_offer_query_direct
    puts "Testing direct Offer query performance..."
    time = Benchmark.measure do
      offers = Offer.where(status: ['active', 'scheduled'])
                   .where('end_time > ?', Time.current)
                   .joins(:seller)
                   .where(sellers: { blocked: false, deleted: false, flagged: false })
                   .by_priority
                   .includes(:seller, :offer_ads, ads: [:category, :subcategory, :reviews, seller: :seller_tier])
                   .limit(100)

      offers_count = offers.count
      offers_loaded = offers.to_a.size

      puts "  - Found #{offers_count} offers, loaded #{offers_loaded}"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def benchmark_offer_with_ads_processing
    puts "Testing offer processing with ads..."
    offers = Offer.where(status: ['active', 'scheduled'])
                 .where('end_time > ?', Time.current)
                 .joins(:seller)
                 .where(sellers: { blocked: false, deleted: false, flagged: false })
                 .by_priority
                 .includes(:seller, :offer_ads, ads: [:category, :subcategory, :reviews, seller: :seller_tier])
                 .limit(10)

    time = Benchmark.measure do
      processed_offers = offers.map do |offer|
        # Simulate the serialization process
        offer_data = {
          id: offer.id,
          name: offer.name,
          offer_type: offer.offer_type,
          discount_type: offer.discount_type,
          ads: offer.ads.map do |ad|
            {
              id: ad.id,
              title: ad.title,
              price: ad.price,
              media: ad.media,
              seller_name: ad.seller&.fullname,
              category_name: ad.category&.name,
              subcategory_name: ad.subcategory&.name
            }
          end
        }
      end

      puts "  - Processed #{processed_offers.size} offers with #{processed_offers.sum { |o| o[:ads].size }} ads"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def run_benchmarks
    puts "Starting deals benchmarks...\n\n"

    results = {}

    puts "=" * 50
    results[:offers_query] = benchmark_offers_query
    puts

    puts "=" * 50
    results[:active_offers_query] = benchmark_active_offers_query
    puts

    puts "=" * 50
    results[:featured_offers_query] = benchmark_featured_offers_query
    puts

    puts "=" * 50
    results[:direct_query] = benchmark_offer_query_direct
    puts

    puts "=" * 50
    results[:processing] = benchmark_offer_with_ads_processing
    puts

    # Summary
    puts "=" * 60
    puts "DEALS PERFORMANCE SUMMARY:"
    puts "=" * 60

    valid_results = results.compact
    if valid_results.any?
      total_time = valid_results.values.sum
      valid_results.each do |component, time|
        percentage = ((time / total_time) * 100).round(1)
        puts "#{component.to_s.upcase}: #{time.round(4)}s (#{percentage}%)"
      end

      puts "\nEstimated deals processing time: #{total_time.round(4)}s (#{total_time * 1000}ms)"

      # Performance assessment
      if total_time < 0.2
        puts "✅ EXCELLENT: Very fast deals processing!"
      elsif total_time < 0.5
        puts "✅ GOOD: Reasonable deals performance"
      elsif total_time < 1.0
        puts "⚠️  SLOW: Deals processing needs optimization"
      else
        puts "❌ CRITICAL: Deals processing is too slow"
      end
    else
      puts "❌ All benchmarks failed - unable to assess performance"
    end
  end
end

# Run the benchmarks
if __FILE__ == $0
  benchmark = DealsBenchmark.new
  benchmark.run_benchmarks
end
