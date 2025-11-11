# Script to normalize the source column in analytics table
# Run with: rails runner lib/scripts/normalize_source_column.rb
#
# This script normalizes the source column (not utm_source) to match UTM source normalization

puts "=" * 80
puts "Normalizing Source Column"
puts "=" * 80
puts ""

# Use the same normalization logic as SourceTrackingService
def normalize_source(source)
  return 'direct' unless source.present?
  
  source_value = source.to_s.split(',').first&.strip
  return 'direct' unless source_value.present?
  
  sanitized = source_value.downcase
  
  case sanitized
  when 'fb', 'face', 'facebbo', 'facebook'
    'facebook'
  when 'ig', 'instagram'
    'instagram'
  when 'tw', 'twitter', 'x'
    'twitter'
  when 'wa', 'whatsapp'
    'whatsapp'
  when 'tg', 'telegram'
    'telegram'
  when 'li', 'linkedin'
    'linkedin'
  when 'yt', 'youtube'
    'youtube'
  when 'tt', 'tiktok'
    'tiktok'
  when 'sc', 'snapchat'
    'snapchat'
  when 'pin', 'pinterest'
    'pinterest'
  when 'reddit', 'rd'
    'reddit'
  when 'google', 'g'
    'google'
  when 'bing', 'b'
    'bing'
  when 'yahoo', 'y'
    'yahoo'
  when '127.0.0.1', 'carboncube-ke.com', 'carboncube.com'
    'direct'
  else
    sanitized
  end
end

# Get all unique source values to see what needs normalization
puts "Analyzing source column..."
all_sources = Analytic.where.not(source: [nil, '']).distinct.pluck(:source).sort
puts "Found #{all_sources.count} unique source values:"
all_sources.each do |source|
  normalized = normalize_source(source)
  if normalized != source.downcase
    puts "  '#{source}' → '#{normalized}' (needs normalization)"
  else
    puts "  '#{source}' (already normalized)"
  end
end

puts ""
puts "Normalizing source column..."

# Normalize each source variation
normalization_map = {
  'fb' => 'facebook',
  'face' => 'facebook',
  'facebbo' => 'facebook',
  'ig' => 'instagram',
  'tw' => 'twitter',
  'x' => 'twitter',
  'wa' => 'whatsapp',
  'tg' => 'telegram',
  'li' => 'linkedin',
  'yt' => 'youtube',
  'tt' => 'tiktok',
  'sc' => 'snapchat',
  'pin' => 'pinterest',
  'rd' => 'reddit',
  'g' => 'google',
  'b' => 'bing',
  'y' => 'yahoo'
}

total_updated = 0
normalization_map.each do |variation, canonical|
  records = Analytic.where("LOWER(source) = ?", variation.downcase)
  count = records.count
  if count > 0
    records.update_all(source: canonical)
    puts "  Normalized '#{variation}' → '#{canonical}': #{count} records"
    total_updated += count
  end
end

# Handle case variations (e.g., "Facebook" → "facebook")
puts ""
puts "Normalizing case variations..."
case_variations = Analytic.where.not(source: [nil, ''])
                           .where("source != LOWER(source)")
                           .select(:source).distinct.pluck(:source)

case_variations.each do |source|
  normalized = normalize_source(source)
  if normalized != source.downcase
    # This is a variation that needs normalization
    records = Analytic.where(source: source)
    count = records.count
    if count > 0
      records.update_all(source: normalized)
      puts "  Normalized case: '#{source}' → '#{normalized}': #{count} records"
      total_updated += count
    end
  else
    # Just fix the case
    records = Analytic.where(source: source)
    count = records.count
    if count > 0
      records.update_all(source: source.downcase)
      puts "  Fixed case: '#{source}' → '#{source.downcase}': #{count} records"
      total_updated += count
    end
  end
end

puts ""
puts "=" * 80
puts "Normalization Complete!"
puts "=" * 80
puts ""
puts "Summary:"
puts "  - Normalized #{total_updated} source column records"
puts ""
puts "Current Source Distribution:"
Analytic.where.not(source: [nil, ''])
        .group(:source)
        .count
        .sort_by { |_, count| -count }
        .each do |source, count|
  puts "  #{source}: #{count}"
end
puts ""
puts "New incoming data will be automatically sanitized by the updated service."
puts "=" * 80

