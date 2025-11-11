# Script to normalize UTM source variations in analytics table
# Run with: rails runner lib/scripts/normalize_utm_sources.rb
#
# This script normalizes UTM source variations to their canonical forms:
# - fb, face, facebbo → facebook
# - ig → instagram
# - tw, x → twitter
# - etc.

puts "=" * 80
puts "Normalizing UTM Source Variations"
puts "=" * 80
puts ""

# Use the same normalization logic as SourceTrackingService
def normalize_utm_source(source)
  return nil unless source.present?
  
  # Handle duplicate parameters (e.g., "google,google")
  source_value = source.to_s.split(',').first&.strip
  return nil unless source_value.present?
  
  # Sanitize and normalize source names
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

def normalize_utm_medium(medium)
  return nil unless medium.present?
  
  # Handle duplicate parameters
  sanitized = medium.to_s.split(',').first&.strip
  return nil unless sanitized.present?
  
  # Normalize UTM medium values
  normalized = sanitized.downcase
  case normalized
  when 'paid_social', 'paid social'
    'paid social'
  when 'social'
    'social' # Keep unpaid/organic social as 'social'
  else
    sanitized
  end
end

# Get all unique UTM sources to see what needs normalization
puts "Analyzing UTM sources..."
all_sources = Analytic.where.not(utm_source: [nil, '']).distinct.pluck(:utm_source).sort
puts "Found #{all_sources.count} unique UTM source values:"
all_sources.each do |source|
  normalized = normalize_utm_source(source)
  if normalized != source.downcase
    puts "  '#{source}' → '#{normalized}' (needs normalization)"
  else
    puts "  '#{source}' (already normalized)"
  end
end

puts ""
puts "Normalizing UTM sources..."

# Normalize each UTM source variation
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
  records = Analytic.where("LOWER(utm_source) = ?", variation.downcase)
  count = records.count
  if count > 0
    records.update_all(utm_source: canonical)
    puts "  Normalized '#{variation}' → '#{canonical}': #{count} records"
    total_updated += count
  end
end

# Handle case variations (e.g., "Facebook" → "facebook")
puts ""
puts "Normalizing case variations..."
case_variations = Analytic.where.not(utm_source: [nil, ''])
                           .where("utm_source != LOWER(utm_source)")
                           .select(:utm_source).distinct.pluck(:utm_source)

case_variations.each do |source|
  normalized = normalize_utm_source(source)
  if normalized != source.downcase
    # This is a variation that needs normalization
    records = Analytic.where(utm_source: source)
    count = records.count
    if count > 0
      records.update_all(utm_source: normalized)
      puts "  Normalized case: '#{source}' → '#{normalized}': #{count} records"
      total_updated += count
    end
  else
    # Just fix the case
    records = Analytic.where(utm_source: source)
    count = records.count
    if count > 0
      records.update_all(utm_source: source.downcase)
      puts "  Fixed case: '#{source}' → '#{source.downcase}': #{count} records"
      total_updated += count
    end
  end
end

# Handle "social_media" as a source (this is likely a mistake - should be medium)
puts ""
puts "Checking for 'social_media' as UTM source..."
social_media_as_source = Analytic.where(utm_source: 'social_media')
if social_media_as_source.any?
  count = social_media_as_source.count
  puts "  Found #{count} records with utm_source='social_media'"
  puts "  'social_media' should be a medium, not a source."
  puts "  Attempting to infer correct source from referrer or setting to 'other'..."
  
  # Try to infer source from referrer
  updated_count = 0
  social_media_as_source.find_each do |analytic|
    inferred_source = nil
    
    # Try to determine source from referrer
    if analytic.referrer.present?
      referrer_domain = analytic.referrer.to_s.downcase
      if referrer_domain.include?('facebook') || referrer_domain.include?('fb.')
        inferred_source = 'facebook'
      elsif referrer_domain.include?('instagram')
        inferred_source = 'instagram'
      elsif referrer_domain.include?('twitter') || referrer_domain.include?('x.com')
        inferred_source = 'twitter'
      elsif referrer_domain.include?('linkedin')
        inferred_source = 'linkedin'
      elsif referrer_domain.include?('youtube')
        inferred_source = 'youtube'
      elsif referrer_domain.include?('tiktok')
        inferred_source = 'tiktok'
      end
    end
    
    # If we couldn't infer, set to 'other'
    inferred_source ||= 'other'
    
    # Update the record: move social_media to medium, set source
    analytic.update_columns(
      utm_source: inferred_source,
      utm_medium: 'social' # social_media should be 'social' medium
    )
    updated_count += 1
  end
  
  puts "  Updated #{updated_count} records:"
  puts "    - Set utm_source based on referrer or 'other'"
  puts "    - Set utm_medium to 'social'"
  total_updated += updated_count
end

# Normalize UTM mediums
puts ""
puts "Normalizing UTM mediums..."
medium_variations = {
  'paid_social' => 'paid social',
  'social_media' => 'social' # social_media as medium should be 'social'
}

medium_total = 0
medium_variations.each do |variation, canonical|
  records = Analytic.where("LOWER(utm_medium) = ?", variation.downcase)
  count = records.count
  if count > 0
    records.update_all(utm_medium: canonical)
    puts "  Normalized '#{variation}' → '#{canonical}': #{count} records"
    medium_total += count
  end
end

# Fix case variations in medium
case_medium_variations = Analytic.where.not(utm_medium: [nil, ''])
                                 .where("utm_medium != LOWER(utm_medium)")
                                 .select(:utm_medium).distinct.pluck(:utm_medium)

case_medium_variations.each do |medium|
  normalized = normalize_utm_medium(medium)
  if normalized != medium.downcase
    records = Analytic.where(utm_medium: medium)
    count = records.count
    if count > 0
      records.update_all(utm_medium: normalized)
      puts "  Normalized case: '#{medium}' → '#{normalized}': #{count} records"
      medium_total += count
    end
  else
    records = Analytic.where(utm_medium: medium)
    count = records.count
    if count > 0
      records.update_all(utm_medium: medium.downcase)
      puts "  Fixed case: '#{medium}' → '#{medium.downcase}': #{count} records"
      medium_total += count
    end
  end
end

puts ""
puts "=" * 80
puts "Normalization Complete!"
puts "=" * 80
puts ""
puts "Summary:"
puts "  - Normalized #{total_updated} UTM source records"
puts "  - Normalized #{medium_total} UTM medium records"
puts ""
puts "Current UTM Source Distribution:"
Analytic.where.not(utm_source: [nil, ''])
        .group(:utm_source)
        .count
        .sort_by { |_, count| -count }
        .each do |source, count|
  puts "  #{source}: #{count}"
end
puts ""
puts "Current UTM Medium Distribution:"
Analytic.where.not(utm_medium: [nil, ''])
        .group(:utm_medium)
        .count
        .sort_by { |_, count| -count }
        .each do |medium, count|
  puts "  #{medium}: #{count}"
end
puts ""
puts "New incoming data will be automatically sanitized by the updated service."
puts "=" * 80

