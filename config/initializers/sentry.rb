if ENV["SENTRY_DSN"].present?
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
