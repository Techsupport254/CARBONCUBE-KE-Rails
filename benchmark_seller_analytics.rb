#!/usr/bin/env ruby
# Benchmark script for seller analytics API
# Usage: rails runner benchmark_seller_analytics.rb [seller_id]

require 'benchmark'
require 'net/http'
require 'json'

# Get seller ID from command line or use a default test seller
seller_id = ARGV[0] || 1

# Get a valid JWT token for the seller
puts "Getting JWT token for seller #{seller_id}..."
seller = Seller.find_by(id: seller_id)
unless seller
  puts "Error: Seller with ID #{seller_id} not found"
  exit 1
end

# Generate a token using JsonWebToken (matching the authentication controller)
token = JsonWebToken.encode({
  seller_id: seller.id,
  email: seller.email,
  role: 'Seller',
  remember_me: true
})

# API endpoint
url = URI("http://localhost:3000/seller/analytics")
http = Net::HTTP.new(url.host, url.port)

# Benchmark the API call
puts "\n" + "="*80
puts "Benchmarking Seller Analytics API"
puts "="*80
puts "Seller ID: #{seller_id}"
puts "Tier: #{seller.seller_tier&.tier_id || 1}"
puts "URL: #{url}"
puts "="*80 + "\n"

times = []
5.times do |i|
  request = Net::HTTP::Get.new(url)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = 'application/json'
  
  time = Benchmark.realtime do
    response = http.request(request)
    if response.code != '200'
      puts "Error: HTTP #{response.code}"
      puts response.body
      exit 1
    end
    data = JSON.parse(response.body)
    puts "Request #{i+1}: #{data.keys.join(', ')}"
  end
  
  times << time
  puts "  Time: #{(time * 1000).round(2)}ms"
  sleep 0.5 # Small delay between requests
end

puts "\n" + "="*80
puts "Results:"
puts "="*80
puts "Average: #{(times.sum / times.size * 1000).round(2)}ms"
puts "Min: #{(times.min * 1000).round(2)}ms"
puts "Max: #{(times.max * 1000).round(2)}ms"
puts "Total: #{(times.sum * 1000).round(2)}ms"
puts "="*80
