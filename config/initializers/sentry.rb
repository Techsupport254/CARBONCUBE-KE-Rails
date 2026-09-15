# Only run Sentry where it can actually reach the ingest endpoint — in
# development/test the SDK otherwise spams "[Tracing] Discarding …" for every
# request and retries failed envelope sends on a loop.
enabled_envs = ENV.fetch("SENTRY_ENABLED_ENVIRONMENTS", "production").split(",").map(&:strip)

if ENV["SENTRY_DSN"].present? && enabled_envs.include?(Rails.env)
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["SENTRY_RELEASE"] if ENV["SENTRY_RELEASE"].present?
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    config.send_default_pii = false
    config.excluded_exceptions += %w[SystemExit Interrupt SignalException]
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.0").to_f
  end
end
