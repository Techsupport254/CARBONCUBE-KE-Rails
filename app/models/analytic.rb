class Analytic < ApplicationRecord
  # Validations - removed conditional validation that was causing 422 errors
  # validates :source, presence: true, if: :source_required?
  
  # Scopes for filtering by source
  scope :by_source, ->(source) { where(source: source) }
  scope :by_utm_source, ->(utm_source) { where(utm_source: utm_source) }
  scope :by_utm_medium, ->(utm_medium) { where(utm_medium: utm_medium) }
  scope :by_utm_campaign, ->(utm_campaign) { where(utm_campaign: utm_campaign) }
  
  # Scope for recent analytics - supports getting all data when days is nil
  scope :recent, ->(days = 30) { days.nil? ? all : where('created_at >= ?', days.days.ago) }
  
  # Class methods for analytics
  def self.source_distribution(days = 30)
    # Group by normalized source where nil or empty strings are bucketed as 'other'
    # This ensures the sum of the distribution equals total visits
    recent(days)
      .group(Arel.sql("COALESCE(NULLIF(source, ''), 'other')"))
      .count
  end
  
  def self.utm_source_distribution(days = 30)
    recent(days).where.not(utm_source: [nil, '']).group(:utm_source).count
  end
  
  def self.utm_medium_distribution(days = 30)
    recent(days).where.not(utm_medium: [nil, '']).group(:utm_medium).count
  end
  
  def self.utm_campaign_distribution(days = 30)
    recent(days).where.not(utm_campaign: [nil, '']).group(:utm_campaign).count
  end
  
  def self.referrer_distribution(days = 30)
    recent(days).where.not(referrer: [nil, '']).group(:referrer).count
  end

  # Unique visitor tracking methods
  def self.unique_visitors_count(days = 30)
    recent(days).where("data->>'visitor_id' IS NOT NULL").distinct.count("data->>'visitor_id'")
  end

  def self.total_visits_count(days = 30)
    recent(days).count
  end

  def self.unique_visitors_by_source(days = 30)
    recent(days)
      .where("data->>'visitor_id' IS NOT NULL")
      .group(:source)
      .distinct.count("data->>'visitor_id'")
  end

  def self.visits_by_source(days = 30)
    recent(days).group(:source).count
  end

  def self.unique_visitors_trend(days = 30)
    recent(days)
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

  def self.returning_visitors_count(days = 30)
    # Count visitors (seen in the recent window) whose first visit was more than 7 days ago
    subquery_sql = recent(days)
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

  def self.new_visitors_count(days = 30)
    # Count visitors (seen in the recent window) whose first visit was within the last 7 days
    subquery_sql = recent(days)
      .where(Arel.sql("data->>'visitor_id' IS NOT NULL"))
      .select(Arel.sql("DISTINCT data->>'visitor_id' AS visitor_id")).to_sql

    first_visits = Analytic
      .where(Arel.sql("data->>'visitor_id' IN (#{subquery_sql})"))
      .group(Arel.sql("data->>'visitor_id'"))
      .minimum(:created_at)

    cutoff = 7.days.ago
    first_visits.values.count { |timestamp| timestamp >= cutoff }
  end

  def self.visitor_engagement_metrics(days = 30)
    recent_analytics = recent(days)
    
    # Calculate average visits per visitor
    total_visits = recent_analytics.count
    unique_visitors = recent_analytics.where("data->>'visitor_id' IS NOT NULL").distinct.count("data->>'visitor_id'")
    
    avg_visits_per_visitor = unique_visitors > 0 ? (total_visits.to_f / unique_visitors).round(2) : 0
    
    {
      total_visits: total_visits,
      unique_visitors: unique_visitors,
      returning_visitors: returning_visitors_count(days),
      new_visitors: new_visitors_count(days),
      avg_visits_per_visitor: avg_visits_per_visitor
    }
  end
end
