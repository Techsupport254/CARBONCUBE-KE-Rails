#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check UTM tracking records in the database
# This shows the actual distribution of UTM parameters

require_relative '../../config/environment'

puts "=" * 80
puts "UTM Campaign Tracking Records Analysis"
puts "=" * 80
puts

# Get all analytics records with complete UTM parameters
# This matches the logic in Analytic.utm_source_distribution
complete_utm_records = Analytic.excluding_internal_users
                                .where.not(utm_source: [nil, '', 'direct', 'other'])
                                .where.not(utm_medium: [nil, ''])
                                .where.not(utm_campaign: [nil, ''])

total_complete_records = complete_utm_records.count
puts "Total records with complete UTM parameters (source + medium + campaign): #{total_complete_records}"
puts

# UTM Source Distribution
puts "-" * 80
puts "UTM Source Distribution"
puts "-" * 80
utm_source_dist = complete_utm_records
                  .group(:utm_source)
                  .count
                  .sort_by { |_, count| -count }

if utm_source_dist.any?
  utm_source_dist.each do |source, count|
    puts "  #{source.ljust(30)} #{count.to_s.rjust(10)}"
  end
else
  puts "  No UTM source data found"
end
puts

# UTM Medium Distribution
puts "-" * 80
puts "UTM Medium Distribution"
puts "-" * 80
utm_medium_dist = complete_utm_records
                  .group(:utm_medium)
                  .count
                  .sort_by { |_, count| -count }

if utm_medium_dist.any?
  utm_medium_dist.each do |medium, count|
    puts "  #{medium.ljust(30)} #{count.to_s.rjust(10)}"
  end
else
  puts "  No UTM medium data found"
end
puts

# UTM Campaign Distribution
puts "-" * 80
puts "UTM Campaign Distribution"
puts "-" * 80
utm_campaign_dist = complete_utm_records
                    .group(:utm_campaign)
                    .count
                    .sort_by { |_, count| -count }

if utm_campaign_dist.any?
  utm_campaign_dist.each do |campaign, count|
    puts "  #{campaign.ljust(30)} #{count.to_s.rjust(10)}"
  end
else
  puts "  No UTM campaign data found"
end
puts

# Show sample records
puts "-" * 80
puts "Sample Records (first 10)"
puts "-" * 80
sample_records = complete_utm_records.limit(10)
sample_records.each_with_index do |record, index|
  puts "\nRecord #{index + 1}:"
  puts "  ID: #{record.id}"
  puts "  Created: #{record.created_at}"
  puts "  Source: #{record.source || 'N/A'}"
  puts "  UTM Source: #{record.utm_source || 'N/A'}"
  puts "  UTM Medium: #{record.utm_medium || 'N/A'}"
  puts "  UTM Campaign: #{record.utm_campaign || 'N/A'}"
  puts "  UTM Content: #{record.utm_content || 'N/A'}"
  puts "  UTM Term: #{record.utm_term || 'N/A'}"
  puts "  Referrer: #{record.referrer || 'N/A'}"
end
puts

# Check for records with incomplete UTM parameters
puts "-" * 80
puts "Records with Incomplete UTM Parameters"
puts "-" * 80

incomplete_records = Analytic.excluding_internal_users.where(
  "(utm_source IS NULL OR utm_source = '' OR utm_source IN ('direct', 'other')) OR 
   (utm_medium IS NULL OR utm_medium = '') OR 
   (utm_campaign IS NULL OR utm_campaign = '')"
)

incomplete_count = incomplete_records.count
puts "Total incomplete UTM records: #{incomplete_count}"

# Breakdown by missing field
missing_source = incomplete_records.where("utm_source IS NULL OR utm_source = '' OR utm_source IN ('direct', 'other')").count
missing_medium = incomplete_records.where("utm_medium IS NULL OR utm_medium = ''").count
missing_campaign = incomplete_records.where("utm_campaign IS NULL OR utm_campaign = ''").count

puts "  Missing/invalid utm_source: #{missing_source}"
puts "  Missing utm_medium: #{missing_medium}"
puts "  Missing utm_campaign: #{missing_campaign}"
puts

# Check for normalization issues (variations that should be normalized)
puts "-" * 80
puts "Potential Normalization Issues"
puts "-" * 80

# Check for Facebook variations
facebook_variations = complete_utm_records
                      .where("LOWER(utm_source) IN (?)", ['fb', 'face', 'facebbo'])
                      .group(:utm_source)
                      .count

if facebook_variations.any?
  puts "Facebook source variations found (should be normalized to 'facebook'):"
  facebook_variations.each do |source, count|
    puts "  #{source}: #{count}"
  end
else
  puts "No Facebook source variations found (good - normalization working)"
end
puts

# Check for medium variations
medium_variations = complete_utm_records
                    .where("LOWER(utm_medium) IN (?)", ['paid_social', 'paid social'])
                    .group(:utm_medium)
                    .count

if medium_variations.any?
  puts "Medium variations found:"
  medium_variations.each do |medium, count|
    puts "  #{medium}: #{count}"
  end
else
  puts "No medium variations found (good - normalization working)"
end
puts

puts "=" * 80
puts "Analysis Complete"
puts "=" * 80

