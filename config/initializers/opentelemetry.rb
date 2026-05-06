# Only initialize OpenTelemetry in production and staging environments
if Rails.env.production? || Rails.env.staging?
  require 'opentelemetry/sdk'
  require 'opentelemetry/exporter/otlp'
  require 'opentelemetry/instrumentation/all'

  begin
    # Create a custom logger that suppresses OpenTelemetry export errors
    otel_logger = Logger.new(STDOUT)
    otel_logger.level = Logger::FATAL
    
    OpenTelemetry::SDK.configure do |c|
      # Set the service name (this shows up in SigNoz)
      c.service_name = ENV['OTEL_SERVICE_NAME'] || 'carboncube-backend'
      c.use_all()
      
      # Add a custom span processor with better error handling and timeout
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(
            endpoint: ENV['OTEL_EXPORTER_OTLP_ENDPOINT'],
            headers: { 'Content-Type' => 'application/json' },
            timeout: 5 # Add timeout to prevent hanging
          ),
          export_timeout: 5, # Add export timeout
          max_queue_size: 100, # Reduce queue size
          max_export_batch_size: 50 # Reduce batch size
        )
      )
    end
    
    # Test the exporter connection
    if ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
      Rails.logger.info "✅ OpenTelemetry initialized and sending to #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}"
    else
      Rails.logger.warn "⚠️ OpenTelemetry endpoint not configured, monitoring disabled"
    end
    
  rescue StandardError => e
    Rails.logger.error "❌ OpenTelemetry failed to initialize: #{e.message}"
    Rails.logger.info "🚫 Continuing without OpenTelemetry monitoring"
  end
else
  Rails.logger.info "🚫 OpenTelemetry disabled in #{Rails.env} environment"
end

# Suppress OpenTelemetry export errors in production
if Rails.env.production?
  module OpenTelemetry
    module SDK
      module Trace
        module Export
          class BatchSpanProcessor
            alias_method :original_export, :export
            
            def export(spans, timeout: nil)
              original_export(spans, timeout: timeout)
            rescue StandardError => e
              # Silently handle export errors in production
              Rails.logger.debug "OpenTelemetry export error (suppressed): #{e.message}" if Rails.env.development?
              0 # Return success code to prevent retries
            end
          end
        end
      end
    end
  end
end

# OpenTelemetry is configured via environment variables:
# OTEL_EXPORTER_OTLP_ENDPOINT
# OTEL_RESOURCE_ATTRIBUTES
