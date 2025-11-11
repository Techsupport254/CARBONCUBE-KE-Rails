class RemoveMisleadingAnalyticsRecords < ActiveRecord::Migration[7.1]
  # Domains that should be considered "direct" traffic
  DIRECT_DOMAINS = ['carboncube-ke.com', 'www.carboncube-ke.com', '188.245.245.79', 'carbon-frontend-next.vercel.app', 'localhost', '127.0.0.1'].freeze

  def up
    # First, update records from direct domains to source='direct' if they don't have broken UTMs
    update_direct_domain_records
    
    # Remove records that fall into "Incomplete UTM" and "Other Sources" categories
    # But exclude records from direct domains (they've been updated to direct)
    
    # Category 1: Records with source='other' (excluding direct domains)
    other_source = Analytic.where(source: 'other')
                           .where.not('referrer LIKE ANY(ARRAY[?])', direct_domain_patterns)
    other_source_count = other_source.count
    puts "Deleting #{other_source_count} records with source='other' (excluding direct domains)..."
    other_source.delete_all
    
    # Category 2: Records with source (not direct/other/empty) but missing UTM params
    # These are incomplete UTM records with a source
    incomplete_with_source = Analytic.where.not(source: ['direct', 'other', nil, ''])
                                     .where('(utm_source IS NULL OR utm_source = \'\' OR utm_source IN (\'direct\', \'other\')) OR (utm_medium IS NULL OR utm_medium = \'\') OR (utm_campaign IS NULL OR utm_campaign = \'\')')
    
    incomplete_with_source_count = incomplete_with_source.count
    puts "Deleting #{incomplete_with_source_count} records with source but incomplete UTM parameters..."
    incomplete_with_source.delete_all
    
    # Category 3: Records with empty source but valid external utm_source (not direct/other) but missing UTM params
    # These are incomplete UTM records with empty source
    incomplete_empty_source = Analytic.where(source: [nil, ''])
                                      .where.not(utm_source: [nil, '', 'direct', 'other'])
                                      .where('(utm_medium IS NULL OR utm_medium = \'\') OR (utm_campaign IS NULL OR utm_campaign = \'\')')
    
    incomplete_empty_source_count = incomplete_empty_source.count
    puts "Deleting #{incomplete_empty_source_count} records with empty source but incomplete UTM parameters..."
    incomplete_empty_source.delete_all
    
    # Category 4: Records with empty source and broken UTM (excluding direct domains)
    # These are "other" records with empty source and broken UTM
    empty_broken_utm = Analytic.where(source: [nil, ''])
                                .where('(utm_source IS NULL OR utm_source = \'\' OR utm_source = \'direct\' OR utm_source = \'other\')')
                                .where.not('referrer LIKE ANY(ARRAY[?])', direct_domain_patterns)
    
    empty_broken_utm_count = empty_broken_utm.count
    puts "Deleting #{empty_broken_utm_count} records with empty source and broken UTM (excluding direct domains)..."
    empty_broken_utm.delete_all
    
    total_deleted = other_source_count + incomplete_with_source_count + incomplete_empty_source_count + empty_broken_utm_count
    puts "Total records deleted: #{total_deleted}"
  end

  private

  def update_direct_domain_records
    puts "Updating records from direct domains to source='direct'..."
    
    # Update records with source='other' from direct domains (if they don't have broken UTMs)
    other_from_direct = Analytic.where(source: 'other')
                                .where('referrer LIKE ANY(ARRAY[?])', direct_domain_patterns)
                                .where.not('(utm_source = \'direct\' OR utm_source = \'other\' OR utm_source IS NULL OR utm_source = \'\') AND (utm_medium IS NULL OR utm_medium = \'\') AND (utm_campaign IS NULL OR utm_campaign = \'\')')
    
    updated_count = other_from_direct.update_all(source: 'direct')
    puts "  Updated #{updated_count} records from 'other' to 'direct' (from direct domains, no broken UTM)"
    
    # Update records with empty source from direct domains (if they don't have broken UTMs)
    # Broken UTM = utm_source='direct'/'other'/empty AND missing medium/campaign
    empty_from_direct = Analytic.where(source: [nil, ''])
                                 .where('referrer LIKE ANY(ARRAY[?])', direct_domain_patterns)
                                 .where.not('(utm_source = \'direct\' OR utm_source = \'other\' OR utm_source IS NULL OR utm_source = \'\') AND (utm_medium IS NULL OR utm_medium = \'\') AND (utm_campaign IS NULL OR utm_campaign = \'\')')
    
    updated_count2 = empty_from_direct.update_all(source: 'direct')
    puts "  Updated #{updated_count2} records from empty source to 'direct' (from direct domains, no broken UTM)"
    
    # Delete records from direct domains that DO have broken UTMs
    broken_utm_from_direct = Analytic.where('referrer LIKE ANY(ARRAY[?])', direct_domain_patterns)
                                     .where('(source = \'other\' OR source IS NULL OR source = \'\') AND ((utm_source = \'direct\' OR utm_source = \'other\' OR utm_source IS NULL OR utm_source = \'\') AND (utm_medium IS NULL OR utm_medium = \'\') AND (utm_campaign IS NULL OR utm_campaign = \'\'))')
    
    deleted_count = broken_utm_from_direct.count
    broken_utm_from_direct.delete_all
    puts "  Deleted #{deleted_count} records from direct domains with broken UTMs"
  end

  def direct_domain_patterns
    # Create SQL LIKE patterns for direct domains
    DIRECT_DOMAINS.map { |domain| "%#{domain}%" }
  end

  def down
    # This migration cannot be reversed as we're deleting data
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse deletion of analytics records"
  end
end
