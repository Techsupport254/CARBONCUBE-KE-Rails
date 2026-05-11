#!/usr/bin/env ruby

require 'bundler/setup'
require_relative 'config/environment'

puts "=== WHATSAPP SENDING BENCHMARK ==="
puts "Time: #{Time.now}"
puts

# Count total sellers with phone numbers
total_sellers = Seller.where.not(phone_number: [nil, '']).count
puts "Total sellers with phone numbers: #{total_sellers}"

# Check recent Sidekiq logs for performance
puts "\n=== RECENT PERFORMANCE (Last 50 log entries) ==="
log_file = Rails.root.join('log', 'sidekiq.log')

if File.exist?(log_file)
  lines = `tail -500 #{log_file}`.split("\n")
  
  # Extract WhatsApp sends with timestamps
  whatsapp_sends = lines.select { |line| line.include?("WhatsApp template sent to") }
  
  if whatsapp_sends.any?
    puts "WhatsApp sends in last 500 lines: #{whatsapp_sends.size}"
    
    # Calculate time between first and last send
    first_send = whatsapp_sends.first
    last_send = whatsapp_sends.last
    
    # Extract timestamps
    first_time = first_send.match(/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)/)
    last_time = last_send.match(/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)/)
    
    if first_time && last_time
      first_timestamp = Time.parse(first_time[1])
      last_timestamp = Time.parse(last_time[1])
      
      duration = last_timestamp - first_timestamp
      sends_per_minute = (whatsapp_sends.size / duration) * 60
      
      puts "Time span: #{duration.round(2)} seconds"
      puts "Sends per minute: #{sends_per_minute.round(2)}"
      puts "Average time per send: #{(duration / whatsapp_sends.size).round(2)} seconds"
      
      # Estimated completion time
      remaining_sends = total_sellers - whatsapp_sends.size
      estimated_time = remaining_sends * (duration / whatsapp_sends.size)
      
      puts "\n=== ESTIMATED COMPLETION ==="
      puts "Remaining sends: #{remaining_sends}"
      puts "Estimated time remaining: #{(estimated_time / 60).round(2)} minutes"
      puts "Estimated completion: #{(Time.now + estimated_time).strftime('%H:%M:%S')}"
    end
  else
    puts "No WhatsApp sends found in recent logs"
  end
  
  # Check current job status
  job_start = lines.select { |line| line.include?("SendProductDetailsToAllSellersJob") && line.include?("start") }.last
  
  if job_start
    start_time_match = job_start.match(/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)/)
    if start_time_match
      job_start_time = Time.parse(start_time_match[1])
      elapsed = Time.now - job_start_time
      puts "\n=== JOB STATUS ==="
      puts "Job started: #{job_start_time.strftime('%H:%M:%S')}"
      puts "Elapsed time: #{(elapsed / 60).round(2)} minutes"
    end
  end
else
  puts "No Sidekiq log file found"
end

puts "\n=== OPTIMIZATION RECOMMENDATIONS ==="
puts "Current delay: 0.5 seconds between sends"
puts "Potential improvements:"
puts "1. Reduce delay to 0.2 seconds (300 sends per minute)"
puts "2. Use parallel processing (multiple Sidekiq workers)"
puts "3. Batch WhatsApp API calls if supported"
puts "4. Remove in-app message sending if not needed"
