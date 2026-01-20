class SearchAnalytic < ApplicationRecord
  validates :date, presence: true, uniqueness: true

  # Serialize arrays for storage in text fields
  serialize :popular_searches_all_time, coder: JSON
  serialize :popular_searches_daily, coder: JSON
  serialize :popular_searches_weekly, coder: JSON
  serialize :popular_searches_monthly, coder: JSON

  # Get analytics for a specific date
  def self.for_date(date)
    find_by(date: date)
  end

  # Get latest analytics
  def self.latest
    order(date: :desc).first
  end

  # Get analytics for date range
  def self.date_range(start_date, end_date)
    where(date: start_date..end_date).order(date: :desc)
  end

  # Get trending searches over a period
  def self.trending_searches(days = 7)
    end_date = Date.current
    start_date = end_date - days.days

    records = date_range(start_date, end_date)

    # Aggregate popular searches across the period
    all_time_searches = records.flat_map { |r| r.popular_searches_all_time || [] }
    search_counts = all_time_searches.tally
    search_counts.sort_by { |_, count| -count }.first(20)
  end
end
