# Script to fix duplicate UTM parameters in analytics table
# Run with: rails runner lib/scripts/fix_duplicate_utm_params.rb

puts "=" * 80
puts "Fixing Duplicate UTM Parameters"
puts "=" * 80
puts ""

# Find and fix duplicate UTM sources (e.g., "google,google")
duplicate_sources = Analytic.where("utm_source LIKE '%,%'")
puts "Found #{duplicate_sources.count} records with duplicate utm_source"

duplicate_sources.find_each do |analytic|
  original = analytic.utm_source
  fixed = original.split(',').first&.strip
  if fixed.present? && fixed != original
    analytic.update_column(:utm_source, fixed)
    puts "  Fixed: '#{original}' → '#{fixed}'"
  end
end

# Find and fix duplicate UTM mediums (e.g., "cpc,cpc")
duplicate_mediums = Analytic.where("utm_medium LIKE '%,%'")
puts ""
puts "Found #{duplicate_mediums.count} records with duplicate utm_medium"

duplicate_mediums.find_each do |analytic|
  original = analytic.utm_medium
  fixed = original.split(',').first&.strip
  if fixed.present? && fixed != original
    analytic.update_column(:utm_medium, fixed)
    puts "  Fixed: '#{original}' → '#{fixed}'"
  end
end

# Find and fix duplicate UTM campaigns (e.g., "campaign,campaign")
duplicate_campaigns = Analytic.where("utm_campaign LIKE '%,%'")
puts ""
puts "Found #{duplicate_campaigns.count} records with duplicate utm_campaign"

duplicate_campaigns.find_each do |analytic|
  original = analytic.utm_campaign
  fixed = original.split(',').first&.strip
  if fixed.present? && fixed != original
    analytic.update_column(:utm_campaign, fixed)
    puts "  Fixed: '#{original}' → '#{fixed}'"
  end
end

# Fix legacy "social_media" to "social"
social_media_records = Analytic.where(utm_medium: 'social_media')
puts ""
puts "Found #{social_media_records.count} records with utm_medium='social_media'"
if social_media_records.any?
  social_media_records.update_all(utm_medium: 'social')
  puts "  Updated 'social_media' → 'social'"
end

# Fix incomplete "paid" to "paid_social"
paid_records = Analytic.where(utm_medium: 'paid')
puts ""
puts "Found #{paid_records.count} records with utm_medium='paid'"
if paid_records.any?
  paid_records.update_all(utm_medium: 'paid_social')
  puts "  Updated 'paid' → 'paid_social'"
end

puts ""
puts "=" * 80
puts "Cleanup Complete!"
puts "=" * 80
puts ""
puts "Summary of changes:"
puts "  - Fixed #{duplicate_sources.count} duplicate utm_source values"
puts "  - Fixed #{duplicate_mediums.count} duplicate utm_medium values"
puts "  - Fixed #{duplicate_campaigns.count} duplicate utm_campaign values"
puts "  - Fixed #{social_media_records.count} 'social_media' → 'social'"
puts "  - Fixed #{paid_records.count} 'paid' → 'paid_social'"
puts ""
puts "New incoming data will be automatically sanitized by the updated service."
puts "=" * 80

