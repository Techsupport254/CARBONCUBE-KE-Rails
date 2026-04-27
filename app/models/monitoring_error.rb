class MonitoringError < ApplicationRecord

  validates :message, presence: true
  validates :level, inclusion: { in: %w[debug info warn error fatal] }

  scope :unresolved, -> { where(resolved_at: nil) }
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  scope :by_level, ->(level) { where(level: level) }

  def to_json_with_context
    as_json(
      methods: [:resolved?, :age_in_hours]
    ).merge(context: context || {})
  end

  def resolved?
    resolved_at.present?
  end

  def age_in_hours
    ((Time.current - created_at) / 1.hour).round(2)
  end
end
