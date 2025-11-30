#!/usr/bin/env ruby
# Test script for optimized buyer_ads_index API
# Run with: rails runner test_optimizations.rb

require 'benchmark'

puts "=== Testing Carbon Buyer Ads Index Optimizations ===\n"

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require_relative 'config/environment'

class OptimizationTester
  include Benchmark

  def initialize
    @controller = Buyer::AdsController.new
  end

  def test_balanced_ads_optimization
    puts "Testing optimized get_balanced_ads method..."
    time = Benchmark.measure do
      result = @controller.send(:get_balanced_ads, 24)
      puts "  - Returned #{result[:ads].size} ads"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def test_best_sellers_optimization
    puts "Testing optimized calculate_best_sellers_fast method..."
    time = Benchmark.measure do
      result = @controller.send(:calculate_best_sellers_fast, 20)
      puts "  - Returned #{result.size} best sellers"
    end
    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def run_tests
    puts "Running optimization tests...\n\n"

    puts "=" * 50
    balanced_time = test_balanced_ads_optimization
    puts

    puts "=" * 50
    best_sellers_time = test_best_sellers_optimization
    puts

    total_optimized = balanced_time + best_sellers_time

    puts "=" * 60
    puts "OPTIMIZATION RESULTS:"
    puts "=" * 60
    puts "Balanced ads: #{balanced_time.round(4)}s (was 0.4587s)"
    puts "Best sellers: #{best_sellers_time.round(4)}s (was 0.7655s)"
    puts "Total optimized: #{total_optimized.round(4)}s (was 1.2242s)"
    puts "Improvement: #{((1.2242 - total_optimized) / 1.2242 * 100).round(1)}% faster"

    if total_optimized < 0.5
      puts "✅ EXCELLENT: Under 500ms total!"
    elsif total_optimized < 0.8
      puts "✅ GOOD: Under 800ms total!"
    else
      puts "⚠️  Still needs work: Over 800ms total"
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = OptimizationTester.new
  tester.run_tests
end
