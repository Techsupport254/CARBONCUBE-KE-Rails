#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
require 'sidekiq'

# Configure Sidekiq
Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

puts '=== Sidekiq Queue Status ==='
stats = Sidekiq::Stats.new
puts "Processed: #{stats.processed}"
puts "Failed: #{stats.failed}"
puts "Enqueued: #{stats.enqueued}"

puts "\n=== Queued Jobs ==="
Sidekiq::Queue.all.each do |queue|
  puts "Queue '#{queue.name}': #{queue.size} jobs"
  queue.each do |job|
    puts "  - #{job.item['class']} (#{job.item['jid']})" if job
  end
end

puts "\n=== Clearing All Queues ==="
total_cleared = 0
Sidekiq::Queue.all.each do |queue|
  cleared_count = queue.size
  queue.clear
  total_cleared += cleared_count
  puts "Cleared #{cleared_count} jobs from queue '#{queue.name}'"
end

puts "\n=== Verification ==="
Sidekiq::Queue.all.each do |queue|
  puts "Queue '#{queue.name}': #{queue.size} jobs remaining"
end

puts "\n✅ Cleared #{total_cleared} total jobs from all queues!"
puts "No emails or messages will be sent to users."
