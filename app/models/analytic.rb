class Analytic < ApplicationRecord
  # Normalize source before saving to prevent duplicate entries like "google,google"
  before_save :normalize_source_field
  
  # Validations - removed conditional validation that was causing 422 errors
  # validates :source, presence: true, if: :source_required?
  
  # Scopes for filtering by source
  scope :by_source, ->(source) { where(source: source) }
  scope :by_utm_source, ->(utm_source) { where(utm_source: utm_source) }
  scope :by_utm_medium, ->(utm_medium) { where(utm_medium: utm_medium) }
  scope :by_utm_campaign, ->(utm_campaign) { where(utm_campaign: utm_campaign) }
  
  # Scope for recent analytics - supports getting all data when days is nil
  scope :recent, ->(days = 30) { days.nil? ? all : where('created_at >= ?', days.days.ago) }
  
  # Scope for date range filtering
  scope :date_range, ->(start_date, end_date) { 
    if start_date && end_date
      where('DATE(created_at) >= ? AND DATE(created_at) <= ?', start_date, end_date)
    else
      all
    end
  }

  # Scope to exclude internal users from analytics
  # This matches the logic in InternalUserExclusion.should_exclude?
  scope :excluding_internal_users, -> {
    # Hardcoded exclusions (always apply these, don't rely on database)
    hardcoded_excluded_emails = ['sales@example.com', 'shangwejunior5@gmail.com']
    hardcoded_excluded_domains = ['example.com']
    
    # Get all active exclusion identifiers from database
    device_hash_exclusions = InternalUserExclusion.active.by_type('device_hash').pluck(:identifier_value)
    email_domain_exclusions = InternalUserExclusion.active.by_type('email_domain').pluck(:identifier_value)
    user_agent_exclusions = InternalUserExclusion.active.by_type('user_agent').pluck(:identifier_value)
    
    # Start with all records
    query = all
    
    # First apply hardcoded email exclusions
    hardcoded_excluded_emails.each do |excluded_email|
      query = query.where(
        "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') != ?) AND (data->>'email' IS NULL OR LOWER(data->>'email') != ?)",
        excluded_email.downcase,
        excluded_email.downcase
      )
    end
    
    # Apply hardcoded domain exclusions
    hardcoded_excluded_domains.each do |excluded_domain|
      query = query.where(
        "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') NOT LIKE ?) AND (data->>'email' IS NULL OR LOWER(data->>'email') NOT LIKE ?)",
        "%@#{excluded_domain.downcase}",
        "%@#{excluded_domain.downcase}"
      )
    end
    
    # Exclude by device hash (from data->>'device_fingerprint')
    if device_hash_exclusions.any?
      device_hash_exclusions.each do |exclusion_hash|
        # Exclude if device_fingerprint matches exclusion exactly or starts with it
        query = query.where(
          "COALESCE(data->>'device_fingerprint', '') NOT LIKE ? AND COALESCE(data->>'device_fingerprint', '') != ?",
          "#{exclusion_hash}%",
          exclusion_hash
        )
        
        # Also exclude device hashes that are variations of the exclusion hash
        base_exclusion = exclusion_hash.gsub(/\d+$/, '')
        if base_exclusion != exclusion_hash && base_exclusion.present?
          query = query.where("COALESCE(data->>'device_fingerprint', '') NOT LIKE ?", "#{base_exclusion}%")
        end
      end
    end
    
    # Exclude by email (from data->>'user_email' or data->>'email') - only process database exclusions not already covered by hardcoded
    database_only_email_exclusions = email_domain_exclusions - hardcoded_excluded_emails - hardcoded_excluded_domains
    if database_only_email_exclusions.any?
      database_only_email_exclusions.each do |email_pattern|
        email_pattern_lower = email_pattern.downcase
        
        # Check for exact email match first
        query = query.where(
          "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') != ?) AND (data->>'email' IS NULL OR LOWER(data->>'email') != ?)",
          email_pattern_lower,
          email_pattern_lower
        )
        
        # Check for domain match (if email_pattern contains @, extract domain; otherwise use as-is)
        if email_pattern.include?('@')
          domain = email_pattern.split('@').last&.downcase
          if domain.present?
            query = query.where(
              "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') NOT LIKE ?) AND (data->>'email' IS NULL OR LOWER(data->>'email') NOT LIKE ?)",
              "%@#{domain}",
              "%@#{domain}"
            )
          end
        else
          # Domain-only exclusion
          query = query.where(
            "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') NOT LIKE ?) AND (data->>'email' IS NULL OR LOWER(data->>'email') NOT LIKE ?)",
            "%@#{email_pattern_lower}",
            "%@#{email_pattern_lower}"
          )
        end
      end
    end
    
    # Exclude by user agent (regex pattern)
    if user_agent_exclusions.any?
      user_agent_exclusions.each do |pattern|
        query = query.where("user_agent IS NULL OR user_agent !~* ?", pattern)
      end
    end
    
    query
  }
  
  # Helper method to get filtered scope (excluding internal users)
  def self.filtered_scope(date_filter)
    base_scope = excluding_internal_users
    if date_filter && date_filter.is_a?(Hash) && date_filter[:start_date] && date_filter[:end_date]
      base_scope.date_range(date_filter[:start_date], date_filter[:end_date])
    else
      base_scope.recent(30)
    end
  end
  
  # Class methods for analytics
  def self.source_distribution(date_filter = nil)
    # Use the source column directly, which is already calculated when visits are tracked
    # This is more accurate and simpler than trying to reconstruct from utm_source/referrer
    scope = filtered_scope(date_filter)
    
    # Group by the source column, defaulting to 'direct' if source is blank
    scope.group(Arel.sql("COALESCE(NULLIF(source, ''), 'direct')")).count
  end
  
  def self.utm_source_distribution(date_filter = nil)
    # Only include UTM sources
    scope = filtered_scope(date_filter)
    
    # Get UTM source counts only
    scope.where.not(utm_source: [nil, '']).group(:utm_source).count
  end
  
  def self.utm_medium_distribution(date_filter = nil)
    filtered_scope(date_filter).where.not(utm_medium: [nil, '']).group(:utm_medium).count
  end
  
  def self.utm_campaign_distribution(date_filter = nil)
    filtered_scope(date_filter).where.not(utm_campaign: [nil, '']).group(:utm_campaign).count
  end
  
  def self.utm_content_distribution(date_filter = nil)
    filtered_scope(date_filter).where.not(utm_content: [nil, '']).group(:utm_content).count
  end
  
  def self.utm_term_distribution(date_filter = nil)
    filtered_scope(date_filter).where.not(utm_term: [nil, '']).group(:utm_term).count
  end
  
  def self.referrer_distribution(date_filter = nil)
    filtered_scope(date_filter).where.not(referrer: [nil, '']).group(:referrer).count
  end

  # Unique visitor tracking methods (excluding internal users)
  def self.unique_visitors_count(days = 30)
    excluding_internal_users.recent(days).where("data->>'visitor_id' IS NOT NULL").distinct.count("data->>'visitor_id'")
  end

  def self.total_visits_count(days = 30)
    excluding_internal_users.recent(days).count
  end

  def self.unique_visitors_by_source(date_filter = nil)
    filtered_scope(date_filter)
      .where("data->>'visitor_id' IS NOT NULL")
      .group(:utm_source)
      .distinct.count("data->>'visitor_id'")
  end

  def self.visits_by_source(date_filter = nil)
    filtered_scope(date_filter).group(:utm_source).count
  end

  def self.unique_visitors_trend(date_filter = nil)
    filtered_scope(date_filter)
      .where("data->>'visitor_id' IS NOT NULL")
      .group("DATE(created_at)")
      .order("DATE(created_at)")
      .distinct.count("data->>'visitor_id'")
  end

  def self.visits_trend(days = 30)
    excluding_internal_users.recent(days)
      .group("DATE(created_at)")
      .order("DATE(created_at)")
      .count
  end

  def self.returning_visitors_count(date_filter = nil)
    # Count visitors (seen in the filtered window) whose first visit was more than 7 days ago
    scope = filtered_scope(date_filter)
    subquery_sql = scope
      .where(Arel.sql("data->>'visitor_id' IS NOT NULL"))
      .select(Arel.sql("DISTINCT data->>'visitor_id' AS visitor_id")).to_sql

    # For those visitors, compute their first-ever visit in a single grouped query
    first_visits = Analytic
      .where(Arel.sql("data->>'visitor_id' IN (#{subquery_sql})"))
      .group(Arel.sql("data->>'visitor_id'"))
      .minimum(:created_at)

    cutoff = 7.days.ago
    first_visits.values.count { |timestamp| timestamp < cutoff }
  end

  def self.new_visitors_count(date_filter = nil)
    # Count visitors (seen in the filtered window) whose first visit was within the last 7 days
    scope = filtered_scope(date_filter)
    subquery_sql = scope
      .where(Arel.sql("data->>'visitor_id' IS NOT NULL"))
      .select(Arel.sql("DISTINCT data->>'visitor_id' AS visitor_id")).to_sql

    first_visits = Analytic
      .where(Arel.sql("data->>'visitor_id' IN (#{subquery_sql})"))
      .group(Arel.sql("data->>'visitor_id'"))
      .minimum(:created_at)

    cutoff = 7.days.ago
    first_visits.values.count { |timestamp| timestamp >= cutoff }
  end

  def self.visitor_engagement_metrics(date_filter = nil)
    scope = filtered_scope(date_filter)
    
    # Calculate average visits per visitor
    total_visits = scope.count
    unique_visitors = scope.where("data->>'visitor_id' IS NOT NULL").distinct.count("data->>'visitor_id'")
    
    avg_visits_per_visitor = unique_visitors > 0 ? (total_visits.to_f / unique_visitors).round(2) : 0
    
    {
      total_visits: total_visits,
      unique_visitors: unique_visitors,
      returning_visitors: returning_visitors_count(date_filter),
      new_visitors: new_visitors_count(date_filter),
      avg_visits_per_visitor: avg_visits_per_visitor
    }
  end
  
  private
  
  def normalize_source_field
    return unless source.present?
    
    # Use the same normalization logic as SourceTrackingService
    self.source = SourceTrackingService.sanitize_source(source)
  end
end
