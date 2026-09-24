class MonitoringMetricJob < ApplicationJob
  queue_as :low

  def perform(controller, action, duration)
    MonitoringService.track_performance(controller, action, duration)
  end
end
