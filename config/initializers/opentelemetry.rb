# OpenTelemetry is configured via environment variables:
# OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_RESOURCE_ATTRIBUTES, OTEL_SERVICE_NAME
# Set OTEL_SDK_DISABLED=true to fully disable (e.g. for the Sidekiq worker container)

# Register a silent error handler FIRST — before anything else — so that
# export failures ("Unable to export N spans") never reach the Rails logger.
# The default OpenTelemetry error handler writes to STDERR/Rails.logger at ERROR
# level; this replaces it with a no-op for export errors.
OpenTelemetry.error_handler = lambda do |exception: nil, message: nil|
  # Silently drop span export failures. Surface everything else at debug level.
  msg = message.to_s
  return if msg.include?('Unable to export') || msg.include?('Export failed')
  return if exception.is_a?(OpenTelemetry::SDK::Trace::Export::ExportError) rescue nil

  Rails.logger.debug("[OpenTelemetry] #{msg}#{exception && " — #{exception.message}"}") if defined?(Rails)
end

if Rails.env.production? || Rails.env.staging?
  # Respect the standard OTEL_SDK_DISABLED env var (set it on the Sidekiq
  # container in Dokploy if you want to opt that service out of tracing).
  if ENV['OTEL_SDK_DISABLED'] == 'true'
    Rails.logger.info '🚫 OpenTelemetry disabled via OTEL_SDK_DISABLED'
  else
    require 'opentelemetry/sdk'
    require 'opentelemetry/exporter/otlp'
    require 'opentelemetry/instrumentation/all'

    begin
      OpenTelemetry::SDK.configure do |c|
        c.service_name = ENV['OTEL_SERVICE_NAME'] || 'carboncube-backend'
        c.use_all()

        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
            OpenTelemetry::Exporter::OTLP::Exporter.new(
              endpoint: ENV['OTEL_EXPORTER_OTLP_ENDPOINT'],
              timeout: 5
            ),
            max_queue_size: 512,
            max_export_batch_size: 50,
            schedule_delay: 5_000  # flush every 5 s instead of 500 ms
          )
        )
      end

      if ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
        Rails.logger.info "✅ OpenTelemetry initialized and sending to #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}"
      else
        Rails.logger.warn '⚠️ OpenTelemetry endpoint not configured, monitoring disabled'
      end

    rescue StandardError => e
      Rails.logger.error "❌ OpenTelemetry failed to initialize: #{e.message}"
    end
  end
else
  Rails.logger.info "🚫 OpenTelemetry disabled in #{Rails.env} environment"
end
