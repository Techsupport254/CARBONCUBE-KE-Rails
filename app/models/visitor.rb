class Visitor < ApplicationRecord
  belongs_to :registered_user, polymorphic: true, optional: true

  validates :visitor_id, presence: true, uniqueness: true
  validates :first_visit_at, presence: true
  validates :last_visit_at, presence: true
  validates :visit_count, numericality: { greater_than: 0 }

  scope :internal_users, -> { where(is_internal_user: true) }
  scope :external_users, -> { where(is_internal_user: false) }
  scope :with_ad_clicks, -> { where(has_clicked_ad: true) }
  scope :registered, -> { where.not(registered_user_id: nil) }
  scope :anonymous, -> { where(registered_user_id: nil) }
  scope :recent, ->(days = 30) { where('last_visit_at >= ?', days.days.ago) }
  scope :by_source, ->(source) { where(first_source: source) }
  scope :by_utm_source, ->(utm_source) { where(first_utm_source: utm_source) }
  scope :date_filtered, ->(date_filter, date_field = :last_visit_at) {
    if date_filter && date_filter[:start_date] && date_filter[:end_date]
      where("#{date_field} >= ? AND #{date_field} <= ?",
            date_filter[:start_date], date_filter[:end_date])
    else
      all
    end
  }

  class << self
    def find_or_create_visitor(visitor_id, attributes = {})
      return nil unless visitor_id.present?

      visitor = find_by(visitor_id: visitor_id)
      return visitor if visitor

      create_visitor(attributes.merge(visitor_id: visitor_id))
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      find_by(visitor_id: visitor_id)
    rescue StandardError => e
      Rails.logger.error "Failed to find/create visitor #{visitor_id}: #{e.message}"
      nil
    end

    def create_visitor(attributes)
      create!(attributes)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Invalid visitor data: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Failed to create visitor: #{e.message}"
      nil
    end

    def unique_visitors_count(date_filter = nil)
      scope = external_users
      apply_date_filter(scope, date_filter).count
    end

    def new_visitors_count(date_filter = nil)
      scope = external_users
      apply_date_filter(scope, date_filter, :first_visit_at).count
    end

    def returning_visitors_count(date_filter = nil)
      scope = external_users.where('visit_count > 1')
      apply_date_filter(scope, date_filter).count
    end

    def visitors_by_source(date_filter = nil)
      scope = external_users
      apply_date_filter(scope, date_filter, :first_visit_at).group(:first_source).count
    end

    def visitors_by_utm_source(date_filter = nil)
      scope = external_users.where.not(first_utm_source: [nil, ''])
      apply_date_filter(scope, date_filter, :first_visit_at).group(:first_utm_source).count
    end

    def conversion_rate
      total = external_users.count.to_f
      converted = external_users.with_ad_clicks.count
      total > 0 ? (converted / total * 100).round(2) : 0
    end

    private

    def apply_date_filter(scope, date_filter, date_field = :last_visit_at)
      if date_filter && date_filter[:start_date] && date_filter[:end_date]
        scope.where("#{date_field} >= ? AND #{date_field} <= ?",
                   date_filter[:start_date], date_filter[:end_date])
      else
        scope
      end
    end
  end

  def update_visit!(visit_data = {})
    now = Time.current

    update_data = { last_visit_at: now, visit_count: visit_count + 1 }

    if visit_data[:ip_address].present? && ip_address.blank?
      update_data.merge!(extract_location_data(visit_data))
    end

    update!(update_data)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Invalid visit update for visitor #{visitor_id}: #{e.message}"
    false
  rescue StandardError => e
    Rails.logger.error "Failed to update visit for visitor #{visitor_id}: #{e.message}"
    false
  end

  def record_ad_click!(click_data = {})
    now = Time.current

    update_data = {
      has_clicked_ad: true,
      ad_click_count: ad_click_count + 1,
      last_ad_click_at: now
    }

    update_data[:first_ad_click_at] = now if first_ad_click_at.nil?

    update!(update_data)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Invalid ad click update for visitor #{visitor_id}: #{e.message}"
    false
  rescue StandardError => e
    Rails.logger.error "Failed to record ad click for visitor #{visitor_id}: #{e.message}"
    false
  end

  def associate_user(user)
    return false if registered_user_id.present? || user.blank?

    update!(
      registered_user_id: user.id,
      registered_user_type: user.class.name
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Invalid user association for visitor #{visitor_id}: #{e.message}"
    false
  rescue StandardError => e
    Rails.logger.error "Failed to associate user with visitor #{visitor_id}: #{e.message}"
    false
  end

  def mark_internal_user
    update!(is_internal_user: true)
  rescue StandardError => e
    Rails.logger.error "Failed to mark visitor #{visitor_id} as internal: #{e.message}"
    false
  end

  private

  def extract_location_data(visit_data)
    {
      ip_address: visit_data[:ip_address],
      country: visit_data[:country],
      city: visit_data[:city],
      region: visit_data[:region],
      timezone: visit_data[:timezone]
    }.compact
  end
end
