#!/usr/bin/env ruby
# Test script for SendBulkSellerCommunicationJob
# Run with: rails runner lib/scripts/test_bulk_seller_email.rb

puts "=== TESTING BULK SELLER EMAIL JOB ==="
puts "Time: #{Time.current}"
puts ""

# First, let's check how many active sellers we have
active_sellers = Seller.where(
  deleted: [false, nil],
  flagged: [false, nil],
  blocked: [false, nil]
)

puts "Active sellers count: #{active_sellers.count}"
puts ""

if active_sellers.count > 0
  puts "Sample of active sellers:"
  active_sellers.limit(5).each do |seller|
    puts "  - ID: #{seller.id}, Name: #{seller.fullname}, Email: #{seller.email}"
    puts "    Deleted: #{seller.deleted}, Flagged: #{seller.flagged}, Blocked: #{seller.blocked}"
  end
  puts ""
end

# Test the job
puts "Testing SendBulkSellerCommunicationJob..."
puts ""

begin
  # Run the job synchronously for testing
  result = SendBulkSellerCommunicationJob.new.perform('general_update')
  
  puts "Job completed successfully!"
  puts "Result: #{result.inspect}"
  
rescue => e
  puts "Job failed with error: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace:"
  e.backtrace.first(10).each { |line| puts "  #{line}" }
end

puts ""
puts "=== TEST COMPLETED ==="
