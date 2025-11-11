# Script to show records with incomplete UTM structure
# Run with: rails runner lib/scripts/show_incomplete_utm_records.rb
#
# Shows records that are missing required UTM parameters (source, medium, or campaign)

puts "=" * 80
puts "Records with Incomplete UTM Structure"
puts "=" * 80
puts ""

# Get records that are NOT clean (missing one or more UTM parameters)
# Exclude internal users
incomplete_records = Analytic.excluding_internal_users.where(
  "utm_source IS NULL OR utm_source = '' OR utm_source IN ('direct', 'other') OR 
   utm_medium IS NULL OR utm_medium = '' OR 
   utm_campaign IS NULL OR utm_campaign = ''"
)

total_count = incomplete_records.count
puts "Total Records with Incomplete UTM: #{total_count}"
puts ""

# Categorize by what's missing
missing_source = incomplete_records.where("utm_source IS NULL OR utm_source = '' OR utm_source IN ('direct', 'other')")
missing_medium = incomplete_records.where("utm_medium IS NULL OR utm_medium = ''")
missing_campaign = incomplete_records.where("utm_campaign IS NULL OR utm_campaign = ''")

puts "Breakdown:"
puts "  Missing or invalid UTM Source: #{missing_source.count}"
puts "  Missing UTM Medium: #{missing_medium.count}"
puts "  Missing UTM Campaign: #{missing_campaign.count}"
puts ""

# Show records with full URLs
records_with_url = incomplete_records.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''").count
puts "Records with Full URL: #{records_with_url} (#{total_count > 0 ? (records_with_url.to_f / total_count * 100).round(2) : 0}%)"
puts ""

# Show sample records grouped by what's missing
puts "=" * 80
puts "Sample Records - Missing UTM Source:"
puts "=" * 80
sample_count = 0
missing_source.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''")
              .order(created_at: :desc)
              .limit(20)
              .each do |record|
  full_url = record.data&.dig('full_url')
  next unless full_url.present?
  
  sample_count += 1
  break if sample_count > 10
  
  # Reconstruct actual page URL from path
  path = record.data&.dig('path') || ''
  actual_url = if path.present? && path != '/source-tracking/track'
    # Extract domain from full_url or use default
    domain = if full_url.present?
      uri = URI.parse(full_url) rescue nil
      "#{uri&.scheme}://#{uri&.host}" if uri
    end
    domain ||= 'https://carboncube-ke.com'
    "#{domain}#{path}"
  else
    full_url
  end
  
  puts ""
  puts "Record ##{record.id}"
  puts "  Created: #{record.created_at&.iso8601}"
  puts "  UTM Source: #{record.utm_source || 'MISSING'}"
  puts "  UTM Medium: #{record.utm_medium || 'MISSING'}"
  puts "  UTM Campaign: #{record.utm_campaign || 'MISSING'}"
  puts "  Source (fallback): #{record.source || 'N/A'}"
  puts "  Actual Page URL: #{actual_url}"
  puts "  Path: #{path || 'N/A'}"
  puts "  Referrer: #{record.referrer || 'N/A'}"
  puts "-" * 80
end

puts ""
puts "=" * 80
puts "Sample Records - Missing UTM Medium:"
puts "=" * 80
sample_count = 0
missing_medium.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''")
              .where.not(utm_source: [nil, '', 'direct', 'other'])
              .order(created_at: :desc)
              .limit(20)
              .each do |record|
  full_url = record.data&.dig('full_url')
  next unless full_url.present?
  
  sample_count += 1
  break if sample_count > 10
  
  # Reconstruct actual page URL from path
  path = record.data&.dig('path') || ''
  actual_url = if path.present? && path != '/source-tracking/track'
    # Extract domain from full_url or use default
    domain = if full_url.present?
      uri = URI.parse(full_url) rescue nil
      "#{uri&.scheme}://#{uri&.host}" if uri
    end
    domain ||= 'https://carboncube-ke.com'
    "#{domain}#{path}"
  else
    full_url
  end
  
  puts ""
  puts "Record ##{record.id}"
  puts "  Created: #{record.created_at&.iso8601}"
  puts "  UTM Source: #{record.utm_source || 'MISSING'}"
  puts "  UTM Medium: #{record.utm_medium || 'MISSING'}"
  puts "  UTM Campaign: #{record.utm_campaign || 'MISSING'}"
  puts "  Actual Page URL: #{actual_url}"
  puts "  Path: #{path || 'N/A'}"
  puts "  Referrer: #{record.referrer || 'N/A'}"
  puts "-" * 80
end

puts ""
puts "=" * 80
puts "Sample Records - Missing UTM Campaign:"
puts "=" * 80
sample_count = 0
missing_campaign.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''")
                .where.not(utm_source: [nil, '', 'direct', 'other'])
                .where.not(utm_medium: [nil, ''])
                .order(created_at: :desc)
                .limit(20)
                .each do |record|
  full_url = record.data&.dig('full_url')
  next unless full_url.present?
  
  sample_count += 1
  break if sample_count > 10
  
  # Reconstruct actual page URL from path
  path = record.data&.dig('path') || ''
  actual_url = if path.present? && path != '/source-tracking/track'
    # Extract domain from full_url or use default
    domain = if full_url.present?
      uri = URI.parse(full_url) rescue nil
      "#{uri&.scheme}://#{uri&.host}" if uri
    end
    domain ||= 'https://carboncube-ke.com'
    "#{domain}#{path}"
  else
    full_url
  end
  
  puts ""
  puts "Record ##{record.id}"
  puts "  Created: #{record.created_at&.iso8601}"
  puts "  UTM Source: #{record.utm_source || 'MISSING'}"
  puts "  UTM Medium: #{record.utm_medium || 'MISSING'}"
  puts "  UTM Campaign: #{record.utm_campaign || 'MISSING'}"
  puts "  Actual Page URL: #{actual_url}"
  puts "  Path: #{path || 'N/A'}"
  puts "  Referrer: #{record.referrer || 'N/A'}"
  puts "-" * 80
end

puts ""
puts "=" * 80
puts "Sample Records - Multiple Missing Parameters:"
puts "=" * 80
sample_count = 0
incomplete_records.where("data->>'full_url' IS NOT NULL AND data->>'full_url' != ''")
                  .where("(utm_source IS NULL OR utm_source = '' OR utm_source IN ('direct', 'other')) AND 
                          (utm_medium IS NULL OR utm_medium = '') AND 
                          (utm_campaign IS NULL OR utm_campaign = '')")
                  .order(created_at: :desc)
                  .limit(20)
                  .each do |record|
  full_url = record.data&.dig('full_url')
  next unless full_url.present?
  
  sample_count += 1
  break if sample_count > 10
  
  # Reconstruct actual page URL from path
  path = record.data&.dig('path') || ''
  actual_url = if path.present? && path != '/source-tracking/track'
    # Extract domain from full_url or use default
    domain = if full_url.present?
      uri = URI.parse(full_url) rescue nil
      "#{uri&.scheme}://#{uri&.host}" if uri
    end
    domain ||= 'https://carboncube-ke.com'
    "#{domain}#{path}"
  else
    full_url
  end
  
  puts ""
  puts "Record ##{record.id}"
  puts "  Created: #{record.created_at&.iso8601}"
  puts "  UTM Source: #{record.utm_source || 'MISSING'}"
  puts "  UTM Medium: #{record.utm_medium || 'MISSING'}"
  puts "  UTM Campaign: #{record.utm_campaign || 'MISSING'}"
  puts "  Source (fallback): #{record.source || 'N/A'}"
  puts "  Actual Page URL: #{actual_url}"
  puts "  Path: #{path || 'N/A'}"
  puts "  Referrer: #{record.referrer || 'N/A'}"
  puts "-" * 80
end

puts ""
puts "=" * 80
puts "Summary:"
puts "=" * 80
puts "Total incomplete records: #{total_count}"
puts "Records with URLs: #{records_with_url}"
puts ""
puts "These records need proper UTM parameters to be included in UTM tracking analytics."
puts "=" * 80

