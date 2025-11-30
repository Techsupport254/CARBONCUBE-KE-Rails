#!/usr/bin/env ruby
# Test script for full API call after optimizations
# Run with: rails runner test_full_api.rb

require 'benchmark'

puts "=== Testing Full Buyer Ads Index API After Optimizations ===\n"

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require_relative 'config/environment'

class FullApiTester
  include Benchmark

  def test_full_api_call
    puts "Testing full buyer_ads_index API call..."

    # Clear any existing cache to test fresh performance
    cache_keys = [
      "buyer_ads_24_1__#{Time.current.to_i / 60}",
      "balanced_ads_24_#{Date.current.strftime('%Y%m%d%H%M')}",
      "best_sellers_optimized_20_#{Date.current.strftime('%Y%m%d')}"
    ]

    cache_keys.each do |key|
      Rails.cache.delete(key)
    end

    # Simulate API call with balanced=true (the slow path from the original issue)
    time = Benchmark.measure do
      controller = Buyer::AdsController.new
      request = ActionDispatch::TestRequest.create
      response = ActionDispatch::Response.new

      controller.request = request
      controller.response = response
      controller.params = { 'per_page' => '24', 'page' => '1', 'balanced' => 'true' }

      # Mock the index action
      begin
        controller.index
        puts "  - API call completed successfully"
      rescue => e
        puts "  - API call failed: #{e.message}"
        return nil
      end
    end

    puts "  - Time: #{time.real.round(4)}s (#{time.real * 1000}ms)"
    time.real
  end

  def run_test
    puts "Running full API test...\n\n"

    puts "=" * 50
    api_time = test_full_api_call
    puts

    if api_time
      puts "=" * 60
      puts "FULL API PERFORMANCE RESULTS:"
      puts "=" * 60
      puts "Full API call: #{api_time.round(4)}s (#{api_time * 1000}ms)"
      puts "Original time was: 1.3226s"
      puts "Improvement: #{((1.3226 - api_time) / 1.3226 * 100).round(1)}% faster"

      if api_time < 0.5
        puts "🎉 EXCELLENT: Under 500ms!"
      elsif api_time < 0.8
        puts "✅ GOOD: Under 800ms!"
      elsif api_time < 1.0
        puts "⚠️  ACCEPTABLE: Under 1 second"
      else
        puts "❌ SLOW: Still over 1 second"
      end
    end
  end
end

# Run the test
if __FILE__ == $0
  tester = FullApiTester.new
  tester.run_test
end
