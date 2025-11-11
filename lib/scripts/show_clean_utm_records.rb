# Script to show clean UTM records with full URLs
# Run with: rails runner lib/scripts/show_clean_utm_records.rb
#
# Shows records with complete UTM parameters and their full URLs

puts "=" * 80
puts "Clean UTM Records (with Full URLs)"
puts "=" * 80
puts ""

# Get clean records: complete UTM parameters (source + medium + campaign) and excludes internal users
clean_records = Analytic.excluding_internal_users
                        .where.not(utm_source: [nil, '', 'direct', 'other'])
                        .where.not(utm_medium: [nil, ''])
                        .where.not(utm_campaign: [nil, ''])

total_count = clean_records.count
puts "Total Clean Records: #{total_count}"
puts ""

# Count records with full URLs
records_with_url = clean_records.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''").count
puts "Records with Full URL: #{records_with_url} (#{total_count > 0 ? (records_with_url.to_f / total_count * 100).round(2) : 0}%)"
puts ""

# Show breakdown by source
puts "Breakdown by UTM Source:"
clean_records.group(:utm_source).count.sort_by { |_, count| -count }.each do |source, count|
  puts "  #{source}: #{count}"
end
puts ""

# Show breakdown by medium
puts "Breakdown by UTM Medium:"
clean_records.group(:utm_medium).count.sort_by { |_, count| -count }.each do |medium, count|
  puts "  #{medium}: #{count}"
end
puts ""

# Show top campaigns
puts "Top 10 UTM Campaigns:"
clean_records.group(:utm_campaign).count.sort_by { |_, count| -count }.first(10).each do |campaign, count|
  puts "  #{campaign}: #{count}"
end
puts ""

# Show sample records with full URLs
puts "Sample Records with Full URLs (first 10):"
puts "=" * 80
sample_count = 0
clean_records.order(created_at: :desc).find_each do |record|
  full_url = record.data&.dig('full_url')
  next unless full_url.present? && full_url != ''
  
  sample_count += 1
  break if sample_count > 10
  
  puts ""
  puts "Record ##{record.id}"
  puts "  Created: #{record.created_at&.iso8601}"
  puts "  UTM Source: #{record.utm_source}"
  puts "  UTM Medium: #{record.utm_medium}"
  puts "  UTM Campaign: #{record.utm_campaign}"
  puts "  UTM Content: #{record.utm_content || 'N/A'}"
  puts "  UTM Term: #{record.utm_term || 'N/A'}"
  puts "  Full URL: #{full_url}"
  puts "  Path: #{record.data&.dig('path') || 'N/A'}"
  puts "  Referrer: #{record.referrer || 'N/A'}"
  puts "-" * 80
end

puts ""
puts "=" * 80
puts "To export all records to CSV, run:"
puts "  rails runner lib/scripts/export_clean_utm_records.rb"
puts "=" * 80

