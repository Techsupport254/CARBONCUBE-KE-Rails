# Script to export clean UTM records with full URLs
# Run with: rails runner lib/scripts/export_clean_utm_records.rb
#
# This script exports records with complete UTM parameters (source + medium + campaign)
# and includes the full URL from the data field

puts "=" * 80
puts "Exporting Clean UTM Records"
puts "=" * 80
puts ""

# Define what constitutes a "clean" record
# Clean = has complete UTM parameters (source + medium + campaign) and excludes internal users
clean_records = Analytic.excluding_internal_users
                        .where.not(utm_source: [nil, '', 'direct', 'other'])
                        .where.not(utm_medium: [nil, ''])
                        .where.not(utm_campaign: [nil, ''])

total_count = clean_records.count
puts "Found #{total_count} clean UTM records"
puts ""

# Ask user if they want to see all records or just a sample
puts "Options:"
puts "  1. Show summary statistics"
puts "  2. Export all records to CSV"
puts "  3. Show sample records (first 20)"
puts "  4. Export specific source/medium/campaign"
puts ""
print "Enter option (1-4) or press Enter for summary: "
option = STDIN.gets.chomp

case option
when '2'
  # Export to CSV
  require 'csv'
  csv_file = "tmp/clean_utm_records_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
  
  CSV.open(csv_file, 'w') do |csv|
    # Header row
    csv << [
      'ID',
      'Created At',
      'UTM Source',
      'UTM Medium',
      'UTM Campaign',
      'UTM Content',
      'UTM Term',
      'Source',
      'Referrer',
      'Full URL',
      'Path',
      'Visitor ID',
      'Session ID',
      'User Agent'
    ]
    
    # Data rows
    clean_records.find_each do |record|
      full_url = record.data&.dig('full_url') || ''
      path = record.data&.dig('path') || ''
      visitor_id = record.data&.dig('visitor_id') || ''
      session_id = record.data&.dig('session_id') || ''
      
      csv << [
        record.id,
        record.created_at&.iso8601,
        record.utm_source,
        record.utm_medium,
        record.utm_campaign,
        record.utm_content || '',
        record.utm_term || '',
        record.source || '',
        record.referrer || '',
        full_url,
        path,
        visitor_id,
        session_id,
        record.user_agent || ''
      ]
    end
  end
  
  puts ""
  puts "✓ Exported #{total_count} records to: #{csv_file}"
  puts ""

when '3'
  # Show sample records
  puts ""
  puts "Sample Records (first 20):"
  puts "=" * 80
  clean_records.limit(20).each do |record|
    full_url = record.data&.dig('full_url') || 'N/A'
    path = record.data&.dig('path') || 'N/A'
    
    puts "ID: #{record.id}"
    puts "  Created: #{record.created_at&.iso8601}"
    puts "  UTM Source: #{record.utm_source}"
    puts "  UTM Medium: #{record.utm_medium}"
    puts "  UTM Campaign: #{record.utm_campaign}"
    puts "  UTM Content: #{record.utm_content || 'N/A'}"
    puts "  UTM Term: #{record.utm_term || 'N/A'}"
    puts "  Full URL: #{full_url}"
    puts "  Path: #{path}"
    puts "  Referrer: #{record.referrer || 'N/A'}"
    puts "-" * 80
  end

when '4'
  # Export specific source/medium/campaign
  puts ""
  print "Enter UTM Source (or press Enter for all): "
  utm_source_filter = STDIN.gets.chomp
  print "Enter UTM Medium (or press Enter for all): "
  utm_medium_filter = STDIN.gets.chomp
  print "Enter UTM Campaign (or press Enter for all): "
  utm_campaign_filter = STDIN.gets.chomp
  
  filtered = clean_records
  filtered = filtered.where(utm_source: utm_source_filter) if utm_source_filter.present?
  filtered = filtered.where(utm_medium: utm_medium_filter) if utm_medium_filter.present?
  filtered = filtered.where(utm_campaign: utm_campaign_filter) if utm_campaign_filter.present?
  
  filtered_count = filtered.count
  puts ""
  puts "Found #{filtered_count} records matching filters"
  
  if filtered_count > 0
    require 'csv'
    csv_file = "tmp/clean_utm_records_filtered_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    
    CSV.open(csv_file, 'w') do |csv|
      csv << [
        'ID',
        'Created At',
        'UTM Source',
        'UTM Medium',
        'UTM Campaign',
        'UTM Content',
        'UTM Term',
        'Source',
        'Referrer',
        'Full URL',
        'Path',
        'Visitor ID',
        'Session ID',
        'User Agent'
      ]
      
      filtered.find_each do |record|
        full_url = record.data&.dig('full_url') || ''
        path = record.data&.dig('path') || ''
        visitor_id = record.data&.dig('visitor_id') || ''
        session_id = record.data&.dig('session_id') || ''
        
        csv << [
          record.id,
          record.created_at&.iso8601,
          record.utm_source,
          record.utm_medium,
          record.utm_campaign,
          record.utm_content || '',
          record.utm_term || '',
          record.source || '',
          record.referrer || '',
          full_url,
          path,
          visitor_id,
          session_id,
          record.user_agent || ''
        ]
      end
    end
    
    puts "✓ Exported #{filtered_count} records to: #{csv_file}"
  end

else
  # Default: Show summary statistics
  puts ""
  puts "Summary Statistics:"
  puts "=" * 80
  puts "Total Clean Records: #{total_count}"
  puts ""
  
  puts "By UTM Source:"
  clean_records.group(:utm_source).count.sort_by { |_, count| -count }.each do |source, count|
    puts "  #{source}: #{count}"
  end
  puts ""
  
  puts "By UTM Medium:"
  clean_records.group(:utm_medium).count.sort_by { |_, count| -count }.each do |medium, count|
    puts "  #{medium}: #{count}"
  end
  puts ""
  
  puts "By UTM Campaign (Top 10):"
  clean_records.group(:utm_campaign).count.sort_by { |_, count| -count }.first(10).each do |campaign, count|
    puts "  #{campaign}: #{count}"
  end
  puts ""
  
  # Check how many have full URLs
  records_with_url = clean_records.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''").count
  puts "Records with Full URL: #{records_with_url} (#{(records_with_url.to_f / total_count * 100).round(2)}%)"
  puts ""
  
  puts "Sample Full URLs (first 5):"
  clean_records.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''")
               .limit(5)
               .each do |record|
    puts "  #{record.data&.dig('full_url')}"
  end
end

puts ""
puts "=" * 80
puts "Done!"
puts "=" * 80

