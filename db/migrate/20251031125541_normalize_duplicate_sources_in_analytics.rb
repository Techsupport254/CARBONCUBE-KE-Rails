class NormalizeDuplicateSourcesInAnalytics < ActiveRecord::Migration[7.1]
  def up
    # Normalize sources that have duplicate comma-separated values (e.g., "google,google" -> "google")
    # This handles cases where Rails concatenated duplicate URL parameters
    
    # Get all unique sources that contain commas
    duplicate_sources = connection.select_all(
      "SELECT DISTINCT source FROM analytics WHERE source LIKE '%,%' AND source IS NOT NULL"
    ).rows.flatten
    
    duplicate_sources.each do |duplicate_source|
      next if duplicate_source.blank?
      
      # Extract the first part before comma and normalize it
      normalized = normalize_source(duplicate_source.split(',').first&.strip)
      
      if normalized.present? && normalized != duplicate_source
        # Update all records with this duplicate source to the normalized version
        connection.execute(
          "UPDATE analytics SET source = #{connection.quote(normalized)} WHERE source = #{connection.quote(duplicate_source)}"
        )
        
        say "Normalized #{duplicate_source} -> #{normalized}", true
      end
    end
    
    # Also normalize case variations (e.g., "Google" -> "google")
    # Handle common source names that might have been capitalized
    common_sources = {
      'Google' => 'google',
      'Facebook' => 'facebook',
      'Instagram' => 'instagram',
      'Twitter' => 'twitter',
      'LinkedIn' => 'linkedin',
      'WhatsApp' => 'whatsapp',
      'Telegram' => 'telegram',
      'YouTube' => 'youtube',
      'TikTok' => 'tiktok',
      'Snapchat' => 'snapchat',
      'Pinterest' => 'pinterest',
      'Reddit' => 'reddit',
      'Bing' => 'bing',
      'Yahoo' => 'yahoo',
      'Direct' => 'direct',
      'Other' => 'other'
    }
    
    common_sources.each do |incorrect, correct|
      connection.execute(
        "UPDATE analytics SET source = #{connection.quote(correct)} WHERE LOWER(source) = LOWER(#{connection.quote(incorrect)}) AND source != #{connection.quote(correct)}"
      )
    end
  end
  
  def down
    # Cannot reverse this migration as we don't know which duplicates existed
    # This is a data cleanup migration
  end
  
  private
  
  def normalize_source(source)
    return 'direct' unless source.present?
    
    # Handle duplicate parameters (e.g., "google,google")
    source_value = source.to_s.split(',').first&.strip
    return 'direct' unless source_value.present?
    
    # Sanitize and normalize source names (matching SourceTrackingService logic)
    sanitized = source_value.downcase
    
    case sanitized
    when 'fb', 'facebook'
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
end

