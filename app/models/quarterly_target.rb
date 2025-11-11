class QuarterlyTarget < ApplicationRecord
  # Associations
  belongs_to :created_by, class_name: 'SalesUser', foreign_key: 'created_by_id'
  belongs_to :approved_by, class_name: 'Admin', foreign_key: 'approved_by_id', optional: true

  # Validations
  validates :metric_type, presence: true, inclusion: { in: %w[total_sellers total_buyers total_ads total_reveal_clicks] }
  validates :year, presence: true, numericality: { only_integer: true, greater_than: 2020, less_than: 2100 }
  validates :quarter, presence: true, inclusion: { in: [1, 2, 3, 4] }
  validates :target_value, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  validates :created_by_id, presence: true
  validate :unique_metric_year_quarter, on: :create

  # Scopes
  scope :for_metric, ->(metric_type) { where(metric_type: metric_type) }
  scope :for_year, ->(year) { where(year: year) }
  scope :for_quarter, ->(quarter) { where(quarter: quarter) }
  scope :approved, -> { where(status: 'approved') }
  scope :pending, -> { where(status: 'pending') }
  scope :current_quarter, -> {
    now = Time.current
    where(year: now.year, quarter: ((now.month - 1) / 3) + 1)
  }

  # Get current quarter target for a metric (returns approved or pending)
  def self.current_target_for(metric_type)
    now = Time.current
    current_year = now.year
    current_quarter = ((now.month - 1) / 3) + 1
    
    # Return approved target first, or pending if no approved exists
    approved_target = approved.for_metric(metric_type)
                             .for_year(current_year)
                             .for_quarter(current_quarter)
                             .order(created_at: :desc)
                             .first
    
    return approved_target if approved_target
    
    # If no approved target, return pending target
    pending.for_metric(metric_type)
           .for_year(current_year)
           .for_quarter(current_quarter)
           .order(created_at: :desc)
           .first
  end

  # Get target for a specific year and quarter
  def self.target_for(metric_type, year, quarter)
    approved.for_metric(metric_type)
            .for_year(year)
            .for_quarter(quarter)
            .order(created_at: :desc)
            .first
  end

  # Instance methods
  def approve!(admin)
    update!(
      status: 'approved',
      approved_by: admin,
      approved_at: Time.current
    )
  end

  def reject!(admin, notes: nil)
    update!(
      status: 'rejected',
      approved_by: admin,
      approved_at: Time.current,
      notes: notes || self.notes
    )
  end

  def pending?
    status == 'pending'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  private

  def unique_metric_year_quarter
    existing = QuarterlyTarget.where(
      metric_type: metric_type,
      year: year,
      quarter: quarter
    ).where.not(id: id).exists?

    if existing
      errors.add(:base, "A target for #{metric_type} in Q#{quarter} #{year} already exists")
    end
  end
end

