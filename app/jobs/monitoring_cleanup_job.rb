# Deletes monitoring rows older than RETENTION — the tables get an INSERT on
# every request and would otherwise grow unboundedly.
class MonitoringCleanupJob < ApplicationJob
  queue_as :low

  RETENTION = 7.days

  def perform
    cutoff = RETENTION.ago
    metrics = MonitoringMetric.where('created_at < ?', cutoff).delete_all
    errors = MonitoringError.where('created_at < ?', cutoff).delete_all
    Rails.logger.info "MonitoringCleanupJob: removed #{metrics} metrics, #{errors} errors older than #{cutoff}"
  end
end
