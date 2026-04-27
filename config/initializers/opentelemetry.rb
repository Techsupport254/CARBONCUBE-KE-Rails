require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

begin
  OpenTelemetry::SDK.configure do |c|
    # Set the service name (this shows up in SigNoz)
    c.service_name = ENV['OTEL_SERVICE_NAME'] || 'carboncube-backend'
    c.use_all()
    
    # Explicitly set the exporter to ensure it uses the protocol from ENV
    # This helps avoid the "Unable to export spans" error
    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: ENV['OTEL_EXPORTER_OTLP_ENDPOINT'],
          protocol: ENV['OTEL_EXPORTER_OTLP_PROTOCOL'] || 'http/protobuf'
        )
      )
    )
  end
  Rails.logger.info "✅ OpenTelemetry initialized and sending to #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}"
rescue StandardError => e
  Rails.logger.error "❌ OpenTelemetry failed to initialize: #{e.message}"
end

# OpenTelemetry is configured via environment variables:
# OTEL_EXPORTER_OTLP_ENDPOINT
# OTEL_RESOURCE_ATTRIBUTES
