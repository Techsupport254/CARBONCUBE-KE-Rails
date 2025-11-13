#!/usr/bin/env ruby
# Benchmark script for /seller/analytics endpoint

require_relative 'config/environment'
require 'benchmark'
require 'json'

# Get a seller for testing (preferably Premium tier)
seller = Seller.joins(:seller_tier).where(seller_tiers: { tier_id: 4 }).first

if seller.nil?
  puts "No Premium tier seller found. Trying any seller..."
  seller = Seller.first
end

if seller.nil?
  puts "ERROR: No seller found in database"
  exit 1
end

puts "=" * 80
puts "Benchmarking /seller/analytics endpoint"
puts "=" * 80
puts "Seller ID: #{seller.id}"
puts "Tier ID: #{seller.seller_tier&.tier_id || 1}"
puts "=" * 80
puts

# Create a mock request and controller instance
class MockRequest
  def headers
    {}
  end
end

# Create controller instance and set current_seller
controller = Seller::AnalyticsController.new
controller.instance_variable_set(:@current_seller, seller)
controller.define_singleton_method(:current_seller) { @current_seller }
controller.define_singleton_method(:params) { {} }
controller.define_singleton_method(:request) { MockRequest.new }

# Warm up
puts "Warming up..."
2.times do
  begin
    controller.index
  rescue => e
    # Ignore errors during warmup
  end
end
puts "Done warming up.\n\n"

# Benchmark
puts "Running benchmark (5 iterations)..."
puts

total_time = 0
response_sizes = []
query_counts = []

5.times do |i|
  # Clear query cache
  ActiveRecord::Base.connection.query_cache.clear
  
  # Enable query logging
  query_log = []
  subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    query_log << event.payload[:sql] unless event.payload[:sql].include?('SCHEMA')
  end
  
  time = Benchmark.realtime do
    begin
      # Capture response
      response = nil
      controller.define_singleton_method(:render) do |options|
        response = options[:json]
      end
      
      controller.index
      
      if response
        json_result = response.to_json
        response_sizes << json_result.bytesize
      else
        response_sizes << 0
      end
    rescue => e
      puts "Error in iteration #{i + 1}: #{e.message}"
      response_sizes << 0
    end
  end
  
  # Unsubscribe
  ActiveSupport::Notifications.unsubscribe(subscriber)
  
  query_count = query_log.length
  query_counts << query_count
  total_time += time
  
  puts "Iteration #{i + 1}:"
  puts "  Time: #{(time * 1000).round(2)}ms"
  puts "  Queries: #{query_count}"
  puts "  Response size: #{response_sizes.last > 0 ? (response_sizes.last / 1024.0).round(2) : 0} KB"
  puts
end

# Calculate statistics
avg_time = total_time / 5.0
avg_size = response_sizes.reject(&:zero?).any? ? response_sizes.reject(&:zero?).sum / response_sizes.reject(&:zero?).length / 1024.0 : 0
avg_queries = query_counts.sum / 5.0
min_time = (response_sizes.reject(&:zero?).any? ? response_sizes.reject(&:zero?).min : 0) / 1024.0
max_time = (response_sizes.reject(&:zero?).any? ? response_sizes.reject(&:zero?).max : 0) / 1024.0

puts "=" * 80
puts "RESULTS"
puts "=" * 80
puts "Average time: #{(avg_time * 1000).round(2)}ms"
puts "Average queries: #{avg_queries.round(0)}"
puts "Min response size: #{min_time.round(2)} KB"
puts "Max response size: #{max_time.round(2)} KB"
puts "Average response size: #{avg_size.round(2)} KB"
puts "=" * 80
