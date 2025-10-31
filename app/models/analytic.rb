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
  
  # Helper method to get filtered scope
  def self.filtered_scope(date_filter)
    if date_filter && date_filter.is_a?(Hash) && date_filter[:start_date] && date_filter[:end_date]
      date_range(date_filter[:start_date], date_filter[:end_date])
    else
      recent(30)
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
  
  def self.referrer_distribution(date_filter = nil)
    filtered_scope(date_filter).where.not(referrer: [nil, '']).group(:referrer).count
  end

  # Unique visitor tracking methods
  def self.unique_visitors_count(days = 30)
    recent(days).where("data->>'visitor_id' IS NOT NULL").distinct.count("data->>'visitor_id'")
  end

  def self.total_visits_count(days = 30)
    recent(days).count
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
    recent(days)
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
