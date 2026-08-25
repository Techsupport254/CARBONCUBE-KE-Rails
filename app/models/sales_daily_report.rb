class SalesDailyReport < ApplicationRecord
  belongs_to :sales_user

  validates :report_date, presence: true
  validates :route_areas, presence: true
  validates :businesses_visited, numericality: { greater_than_or_equal_to: 0 }
  validates :businesses_onboarded, numericality: { greater_than_or_equal_to: 0 }
  validates :sales_user_id, uniqueness: { scope: :report_date, message: 'already submitted a report for this date' }

  scope :recent, -> { order(report_date: :desc, created_at: :desc) }
  scope :for_date, ->(date) { where(report_date: date) }
  scope :by_sales_user, ->(user_id) { where(sales_user_id: user_id) }

  def self.today_for_user(user_id)
    today = FieldLocationRedisService.eat_today rescue Date.current
    find_by(sales_user_id: user_id, report_date: today)
  end
end
