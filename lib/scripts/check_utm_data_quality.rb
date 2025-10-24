# Script to check UTM data quality and identify incorrect values
# Run with: rails runner lib/scripts/check_utm_data_quality.rb

puts "=" * 80
puts "UTM Data Quality Report"
puts "=" * 80
puts ""

# Valid UTM medium values according to the dropdown
valid_mediums = %w[social paid_social cpc email referral affiliate display organic]

# Get all UTM medium values from database
utm_mediums = Analytic.where.not(utm_medium: [nil, ''])
                      .group(:utm_medium)
                      .count
                      .sort_by { |_, count| -count }

puts "Current UTM Medium Values in Database:"
puts "-" * 80
puts "%-30s | %-10s | %s" % ["UTM Medium", "Count", "Status"]
puts "-" * 80

utm_mediums.each do |medium, count|
  status = valid_mediums.include?(medium) ? "✅ Valid" : "❌ Invalid"
  puts "%-30s | %-10s | %s" % [medium, count, status]
end

puts ""
puts "=" * 80

# Get invalid values
invalid_mediums = utm_mediums.reject { |medium, _| valid_mediums.include?(medium) }

if invalid_mediums.any?
  puts "⚠️  Found #{invalid_mediums.length} invalid UTM medium values"
  puts ""
  puts "Recommended Actions:"
  puts "-" * 80
  
  invalid_mediums.each do |medium, count|
    suggestion = case medium
    when 'social_media'
      "Should be 'social'"
    when 'facebook', 'instagram', 'twitter', 'linkedin', 'google'
      "This is a SOURCE, not a MEDIUM. Should use utm_source=#{medium} with utm_medium=social or paid_social"
    when 'paid'
      "Incomplete - should be 'paid_social' or specify type"
    when /,/
      "Duplicate/malformed - contains comma separator"
    else
      "Unknown - review and update"
    end
    
    puts "#{medium} (#{count} records): #{suggestion}"
  end
  
  puts ""
  puts "To fix these, you can either:"
  puts "1. Update the records in database (data cleanup)"
  puts "2. Add legacy values to dropdown (backwards compatibility)"
  puts "3. Both (recommended)"
else
  puts "✅ All UTM medium values are valid!"
end

puts "=" * 80

