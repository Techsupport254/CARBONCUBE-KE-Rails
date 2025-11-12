#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to fix UTM normalization issues found in the database
# This fixes:
# 1. Facebook variations (fb, face, facebbo → facebook)
# 2. Medium variations (paid_social → paid social)
# 3. Invalid sources (copy, social_media)

require_relative '../../config/environment'

puts "=" * 80
puts "Fixing UTM Normalization Issues"
puts "=" * 80
puts

total_updated = 0

# 1. Fix Facebook source variations
puts "1. Normalizing Facebook source variations..."
facebook_variations = {
  'fb' => 'facebook',
  'face' => 'facebook',
  'facebbo' => 'facebook'
}

facebook_variations.each do |variation, canonical|
  records = Analytic.where("LOWER(utm_source) = ?", variation.downcase)
  count = records.count
  if count > 0
    records.update_all(utm_source: canonical)
    puts "  ✓ Normalized '#{variation}' → '#{canonical}': #{count} records"
    total_updated += count
  end
end
puts

# 2. Fix medium variations (paid_social → paid social)
puts "2. Normalizing UTM medium variations..."
# Fix paid_social (with underscore) to paid social (with space)
records = Analytic.where("LOWER(utm_medium) = ?", 'paid_social')
count = records.count
if count > 0
  records.update_all(utm_medium: 'paid social')
  puts "  ✓ Normalized 'paid_social' → 'paid social': #{count} records"
  total_updated += count
end
puts

# 3. Handle invalid UTM sources
puts "3. Handling invalid UTM sources..."

# 3a. 'copy' is not a valid source - these should be removed or set to nil
# Since they have complete UTM params, we'll set utm_source to nil to exclude them
copy_records = Analytic.where("LOWER(utm_source) = ?", 'copy')
copy_count = copy_records.count
if copy_count > 0
  # Check if we can infer the source from referrer
  copy_records.find_each do |record|
    inferred_source = nil
    
    if record.referrer.present?
      referrer_domain = record.referrer.to_s.downcase
      if referrer_domain.include?('facebook') || referrer_domain.include?('fb.')
        inferred_source = 'facebook'
      elsif referrer_domain.include?('instagram')
        inferred_source = 'instagram'
      elsif referrer_domain.include?('linkedin')
        inferred_source = 'linkedin'
      end
    end
    
    # If we can't infer, set to nil (will be excluded from UTM distributions)
    record.update_column(:utm_source, inferred_source) if inferred_source
  end
  
  # For records we couldn't infer, set to nil
  remaining = copy_records.where(utm_source: 'copy').count
  if remaining > 0
    copy_records.where(utm_source: 'copy').update_all(utm_source: nil)
    puts "  ✓ Removed invalid 'copy' source from #{remaining} records (set to nil)"
  end
  
  if copy_count > 0
    puts "  ✓ Handled 'copy' source: #{copy_count} records"
    total_updated += copy_count
  end
end

# 3b. 'social_media' is not a valid source - it should be a medium
# Try to infer the correct source from referrer or set to nil
social_media_as_source = Analytic.where("LOWER(utm_source) = ?", 'social_media')
social_media_count = social_media_as_source.count
if social_media_count > 0
  updated_count = 0
  social_media_as_source.find_each do |record|
    inferred_source = nil
    
    # Try to determine source from referrer
    if record.referrer.present?
      referrer_domain = record.referrer.to_s.downcase
      if referrer_domain.include?('facebook') || referrer_domain.include?('fb.')
        inferred_source = 'facebook'
      elsif referrer_domain.include?('instagram')
        inferred_source = 'instagram'
      elsif referrer_domain.include?('linkedin')
        inferred_source = 'linkedin'
      elsif referrer_domain.include?('twitter') || referrer_domain.include?('x.com')
        inferred_source = 'twitter'
      end
    end
    
    # If we can't infer, set to nil (will be excluded from UTM distributions)
    if inferred_source
      record.update_columns(
        utm_source: inferred_source,
        utm_medium: record.utm_medium || 'social'
      )
      updated_count += 1
    else
      record.update_column(:utm_source, nil)
    end
  end
  
  puts "  ✓ Handled 'social_media' as source: #{social_media_count} records"
  puts "    - Inferred source from referrer for #{updated_count} records"
  puts "    - Set to nil for #{social_media_count - updated_count} records (couldn't infer)"
  total_updated += social_media_count
end
puts

puts "=" * 80
puts "Normalization Complete!"
puts "=" * 80
puts "Total records updated: #{total_updated}"
puts

# Show updated distributions
puts "Updated UTM Source Distribution:"
complete_utm_records = Analytic.excluding_internal_users
                                .where.not(utm_source: [nil, '', 'direct', 'other'])
                                .where.not(utm_medium: [nil, ''])
                                .where.not(utm_campaign: [nil, ''])

utm_source_dist = complete_utm_records
                  .group(:utm_source)
                  .count
                  .sort_by { |_, count| -count }

utm_source_dist.each do |source, count|
  puts "  #{source.ljust(30)} #{count.to_s.rjust(10)}"
end
puts

puts "Updated UTM Medium Distribution:"
utm_medium_dist = complete_utm_records
                  .group(:utm_medium)
                  .count
                  .sort_by { |_, count| -count }

utm_medium_dist.each do |medium, count|
  puts "  #{medium.ljust(30)} #{count.to_s.rjust(10)}"
end
puts

puts "=" * 80

