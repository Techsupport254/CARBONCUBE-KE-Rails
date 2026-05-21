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
      begin
        start_time = Date.parse(start_date.to_s).beginning_of_day
        end_time = Date.parse(end_date.to_s).end_of_day
        where(created_at: start_time..end_time)
      rescue Date::Error, ArgumentError
        all
      end
    else
      all
    end
  }

  def self.cached_exclusion_lists
    Rails.cache.fetch('analytic_exclusion_lists', expires_in: 5.minutes) do
      {
        device_hash_exclusions: InternalUserExclusion.active.by_type('device_hash').pluck(:identifier_value),
        email_domain_exclusions: InternalUserExclusion.active.by_type('email_domain').pluck(:identifier_value),
        user_agent_exclusions: InternalUserExclusion.active.by_type('user_agent').pluck(:identifier_value)
      }
    end
  end

  # Scope to exclude internal users from analytics
  # This matches the logic in InternalUserExclusion.should_exclude?
  scope :excluding_internal_users, -> {
    # Get cached exclusions
    exclusions = cached_exclusion_lists
    device_hash_exclusions = exclusions[:device_hash_exclusions] || []
    email_domain_exclusions = exclusions[:email_domain_exclusions] || []
    user_agent_exclusions = exclusions[:user_agent_exclusions] || []
    
    # Hardcoded exclusions (always apply these, don't rely on database)
    hardcoded_excluded_emails = ['sales@example.com', 'shangwejunior5@gmail.com']
    hardcoded_excluded_domains = ['example.com']
    
    query = all
    
    # 1. Batch email exclusions using NOT IN
    emails_to_exclude = (hardcoded_excluded_emails + email_domain_exclusions.select { |p| p.include?('@') }).map(&:downcase).uniq
    if emails_to_exclude.any?
      query = query.where(
        "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') NOT IN (?)) AND (data->>'email' IS NULL OR LOWER(data->>'email') NOT IN (?))",
        emails_to_exclude, emails_to_exclude
      )
    end
    
    # 2. Batch domain exclusions using regex
    domains_to_exclude = (hardcoded_excluded_domains + email_domain_exclusions.reject { |p| p.include?('@') }).map(&:downcase).uniq
    if domains_to_exclude.any?
      domain_regex = domains_to_exclude.map { |d| "@#{Regexp.escape(d)}$" }.join('|')
      query = query.where(
        "(data->>'user_email' IS NULL OR LOWER(data->>'user_email') !~* ?) AND (data->>'email' IS NULL OR LOWER(data->>'email') !~* ?)",
        domain_regex, domain_regex
      )
    end
    
    # 3. Batch device hash exclusions using regex
    if device_hash_exclusions.any?
      hash_regex = device_hash_exclusions.map { |h| "^#{Regexp.escape(h)}" }.join('|')
      query = query.where("COALESCE(data->>'device_fingerprint', '') !~* ?", hash_regex)
    end
    
    # 4. Batch user agent exclusions using regex
    if user_agent_exclusions.any?
      ua_regex = user_agent_exclusions.join('|')
      query = query.where("user_agent IS NULL OR user_agent !~* ?", ua_regex)
    end
    
    query
  }
  
  # Helper method to get filtered scope (excluding internal users)
  def self.filtered_scope(date_filter)
    base_scope = excluding_internal_users
    if date_filter && date_filter.is_a?(Hash) && date_filter[:start_date] && date_filter[:end_date]
      base_scope.date_range(date_filter[:start_date], date_filter[:end_date])
    else
      # Return all records (not limited to 30 days) for data integrity
      base_scope
    end
  end
  
  # Class methods for analytics
  def self.source_distribution(date_filter = nil)
    # Use the source column directly, which is already calculated when visits are tracked
    # This is more accurate and simpler than trying to reconstruct from utm_source/referrer
    scope = filtered_scope(date_filter)
    
    # Handle source distribution correctly:
    # 1. If source is present and not empty, use it (this is the primary source)
    # 2. If source is empty but utm_source is present and valid (not 'direct', not 'other'), use utm_source
    # 3. If source is empty and utm_source is 'direct' or empty/null, this is broken UTM - count as 'other'
    # 4. Only count as 'direct' if source='direct' (regardless of utm_source, since source takes priority)
    # Grouping is case-insensitive.
    scope.group(
      Arel.sql(
        "CASE 
          WHEN source IS NOT NULL AND source != '' THEN LOWER(source)
          WHEN utm_source IS NOT NULL AND utm_source != '' AND utm_source NOT IN ('direct', 'other') THEN LOWER(utm_source)
          ELSE 'other'
        END"
      )
    ).count
  end
  
  def self.utm_source_distribution(date_filter = nil)
    # Exclude 'direct' and 'other' which are fallback values, not real UTM sources
    # Grouping is case-insensitive.
    filtered_scope(date_filter)
         .where.not(utm_source: [nil, '', 'direct', 'other'])
         .group(Arel.sql("LOWER(utm_source)"))
         .count
  end
  
  def self.utm_medium_distribution(date_filter = nil)
    # Grouping is case-insensitive.
    filtered_scope(date_filter)
         .where.not(utm_medium: [nil, ''])
         .group(Arel.sql("LOWER(utm_medium)"))
         .count
  end
  
  def self.utm_campaign_distribution(date_filter = nil)
    # Grouping is case-insensitive.
    filtered_scope(date_filter)
         .where.not(utm_campaign: [nil, ''])
         .group(Arel.sql("LOWER(utm_campaign)"))
         .count
  end
  
  def self.utm_content_distribution(date_filter = nil)
    # Grouping is case-insensitive.
    filtered_scope(date_filter)
         .where.not(utm_content: [nil, ''])
         .group(Arel.sql("LOWER(utm_content)"))
         .count
  end
  
  def self.utm_term_distribution(date_filter = nil)
    # Grouping is case-insensitive.
    filtered_scope(date_filter)
         .where.not(utm_term: [nil, ''])
         .group(Arel.sql("LOWER(utm_term)"))
         .count
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
      .group(
        Arel.sql(
          "CASE
            WHEN source IS NOT NULL AND source != '' THEN LOWER(source)
            WHEN utm_source IS NOT NULL AND utm_source != '' AND utm_source NOT IN ('direct', 'other') THEN LOWER(utm_source)
            ELSE 'other'
          END"
        )
      )
      .distinct.count("data->>'visitor_id'")
  end

  def self.visits_by_source(date_filter = nil)
    filtered_scope(date_filter)
      .group(
        Arel.sql(
          "CASE
            WHEN source IS NOT NULL AND source != '' THEN LOWER(source)
            WHEN utm_source IS NOT NULL AND utm_source != '' AND utm_source NOT IN ('direct', 'other') THEN LOWER(utm_source)
            ELSE 'other'
          END"
        )
      )
      .count
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
