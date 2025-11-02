class ClickEvent < ApplicationRecord
  belongs_to :buyer, optional: true
  belongs_to :ad, optional: true

  EVENT_TYPES = %w[Ad-Click Reveal-Seller-Details Add-to-Cart Add-to-Wish-List].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  # validates :metadata, presence: true, if: -> { event_type == 'Reveal-Seller-Details' } # Example: require metadata for certain event types

  # Scope to find the most common click types
  scope :popular_events, ->(limit = 10) {
    group(:event_type).order('COUNT(event_type) DESC').limit(limit).count
  }

  # Scope to filter clicks by a specific ad
  scope :for_ad, ->(ad_id) { where(ad_id: ad_id) }

  # Scope to exclude internal users from analytics
  # This matches the logic in InternalUserExclusion.should_exclude?
  scope :excluding_internal_users, -> {
    # Get all active exclusion identifiers
    device_hash_exclusions = InternalUserExclusion.active.by_type('device_hash').pluck(:identifier_value)
    email_domain_exclusions = InternalUserExclusion.active.by_type('email_domain').pluck(:identifier_value)
    user_agent_exclusions = InternalUserExclusion.active.by_type('user_agent').pluck(:identifier_value)
    
    # If no exclusions configured, return all
    return all if device_hash_exclusions.empty? && email_domain_exclusions.empty? && user_agent_exclusions.empty?
    
    # Start with all records
    query = all
    
    # Exclude by device hash
    # Logic: If metadata device_hash starts with exclusion hash OR exclusion hash starts with device_hash base
    # This handles cases like exclusion="q4bjv0" should exclude "q4bjv0", "q4bjv01", "q4bjv02", etc.
    if device_hash_exclusions.any?
      device_hash_exclusions.each do |exclusion_hash|
        # Exclude if device_hash matches exclusion exactly or starts with it
        query = query.where(
          "COALESCE(metadata->>'device_hash', '') NOT LIKE ? AND COALESCE(metadata->>'device_hash', '') != ?",
          "#{exclusion_hash}%",
          exclusion_hash
        )
        
        # Also exclude device hashes that are variations of the exclusion hash
        # (e.g., if exclusion is "q4bjv0", exclude "q4bjv01", "q4bjv02" by checking base hash)
        base_exclusion = exclusion_hash.gsub(/\d+$/, '')
        if base_exclusion != exclusion_hash && base_exclusion.present?
          # Exclude hashes that start with the base exclusion hash
          query = query.where("COALESCE(metadata->>'device_hash', '') NOT LIKE ?", "#{base_exclusion}%")
        end
      end
    end
    
    # Exclude by email (from buyers table or metadata)
    # This matches InternalUserExclusion.email_domain_excluded? logic exactly
    if email_domain_exclusions.any?
      query = query.left_joins(:buyer)
      email_domain_exclusions.each do |email_pattern|
        email_pattern_lower = email_pattern.downcase
        
        # InternalUserExclusion.email_domain_excluded? does two checks:
        # 1. Exact email match: if identifier_value equals the email exactly
        # 2. Domain match: extracts domain from email and checks if identifier_value matches domain
        
        # Check for exact email match first
        query = query.where(
          "(buyers.email IS NULL OR LOWER(buyers.email) != ?) AND (metadata->>'user_email' IS NULL OR LOWER(metadata->>'user_email') != ?)",
          email_pattern_lower,
          email_pattern_lower
        )
        
        # Check for domain match (if email_pattern contains @, extract domain; otherwise use as-is)
        if email_pattern.include?('@')
          domain = email_pattern.split('@').last&.downcase
          if domain.present?
            # Exclude emails from this domain
            # Also check if identifier_value contains the domain (matching the LIKE pattern in email_domain_excluded?)
            query = query.where(
              "(buyers.email IS NULL OR LOWER(buyers.email) NOT LIKE ?) AND (metadata->>'user_email' IS NULL OR LOWER(metadata->>'user_email') NOT LIKE ?)",
              "%@#{domain}",
              "%@#{domain}"
            )
          end
        else
          # Domain-only exclusion - exclude emails from this domain
          # Also check if identifier_value matches domain (exact match) or contains it (LIKE pattern)
          query = query.where(
            "(buyers.email IS NULL OR LOWER(buyers.email) NOT LIKE ?) AND (metadata->>'user_email' IS NULL OR LOWER(metadata->>'user_email') NOT LIKE ?)",
            "%@#{email_pattern_lower}",
            "%@#{email_pattern_lower}"
          )
        end
      end
    end
    
    # Exclude by user agent (regex pattern)
    # This matches InternalUserExclusion.user_agent_excluded? logic
    if user_agent_exclusions.any?
      user_agent_exclusions.each do |pattern|
        # Use PostgreSQL regex matching (!~* means does not match case-insensitive)
        query = query.where(
          "metadata->>'user_agent' IS NULL OR metadata->>'user_agent' !~* ?",
          pattern
        )
      end
    end
    
    query
  }
  
  # Check if this event is from an internal user
  def internal_user?
    metadata_hash = metadata || {}
    device_hash = metadata_hash['device_hash'] || metadata_hash[:device_hash]
    user_agent = metadata_hash['user_agent'] || metadata_hash[:user_agent]
    email = buyer&.email || metadata_hash['user_email'] || metadata_hash[:user_email]
    
    InternalUserExclusion.should_exclude?(
      device_hash: device_hash,
      user_agent: user_agent,
      email: email
    )
  end
end
