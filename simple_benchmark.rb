#!/usr/bin/env ruby

require 'bundler/setup'
require_relative 'config/environment'

puts "=== WHATSAPP SENDING PERFORMANCE ANALYSIS ==="
puts

# Check the current job's performance by looking at timestamps
log_file = Rails.root.join('log', 'sidekiq.log')

if File.exist?(log_file)
  # Get the last 1000 lines
  lines = `tail -1000 #{log_file}`.split("\n")
  
  # Find the job start time
  job_start_line = lines.select { |line| line.include?("SendProductDetailsToAllSellersJob") && line.include?("start") }.last
  
  if job_start_line
    start_time_match = job_start_line.match(/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)/)
    if start_time_match
      job_start_time = Time.parse(start_time_match[1])
      
      # Count WhatsApp sends in the same time period
      whatsapp_sends = lines.select { |line| line.include?("WhatsApp template sent to") }
      
      if whatsapp_sends.any?
        last_send_time = Time.parse(whatsapp_sends.last.match(/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z)/)[1])
        elapsed_time = last_send_time - job_start_time
        
        puts "Job started: #{job_start_time.strftime('%H:%M:%S')}"
        puts "Current time: #{last_send_time.strftime('%H:%M:%S')}"
        puts "Elapsed time: #{elapsed_time.round(2)} seconds (#{(elapsed_time / 60).round(2)} minutes)"
        puts "WhatsApp messages sent: #{whatsapp_sends.size}"
        puts "Rate: #{(whatsapp_sends.size / elapsed_time * 60).round(2)} messages per minute"
        puts "Average time per message: #{(elapsed_time / whatsapp_sends.size).round(3)} seconds"
        
        # Total sellers estimate
        total_sellers = Seller.where.not(phone_number: [nil, '']).count
        remaining = total_sellers - whatsapp_sends.size
        estimated_total_time = (total_sellers * (elapsed_time / whatsapp_sends.size)) / 60
        
        puts "\n=== PROJECTION ==="
        puts "Total sellers with phones: #{total_sellers}"
        puts "Remaining to send: #{remaining}"
        puts "Estimated total time: #{estimated_total_time.round(2)} minutes"
        puts "Estimated completion time: #{(Time.now + (remaining * (elapsed_time / whatsapp_sends.size))).strftime('%H:%M:%S')}"
        
        puts "\n=== PERFORMANCE ISSUES ==="
        if (whatsapp_sends.size / elapsed_time * 60) < 60
          puts "⚠️  SLOW: Less than 60 messages per minute"
          puts "Current delay of 0.5 seconds is too conservative"
          puts "Recommend reducing to 0.2 seconds for 300 messages/minute"
        end
      else
        puts "No WhatsApp sends found in recent logs"
      end
    else
      puts "Could not parse job start time"
    end
  else
    puts "No job start found in logs"
  end
else
  puts "No Sidekiq log file found"
end
