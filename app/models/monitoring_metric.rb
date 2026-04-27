class MonitoringMetric < ApplicationRecord

  validates :name, presence: true
  validates :value, presence: true

  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  scope :by_name, ->(name) { where(name: name) }

  def to_json_with_tags
    as_json(
      methods: [:formatted_value],
      include: { tags: {} }
    )
  end

  def formatted_value
    case name
    when 'request_duration_ms'
      "#{value.round(2)}ms"
    when 'database_query_ms'
      "#{value.round(2)}ms"
    else
      value.to_s
    end
  end
end
