require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present? || ENV['RENDER'].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  # config.assets.compile = false  # Commented out for API-only app

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # Configure Action Cable to align with Nginx `/cable` proxy and HTTPS
  config.action_cable.mount_path = "/cable"
  config.action_cable.url = "wss://carboncube-ke.com/cable"
  config.action_cable.allowed_request_origins = [
    "https://carboncube-ke.com",
    "https://www.carboncube-ke.com",
    "http://localhost",
    "https://localhost"
  ]
  
  # Enable WebSocket debugging
  config.action_cable.disable_request_forgery_protection = true

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "carbonecomrails_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts << "carboncube-ke.com"
  config.hosts << "www.carboncube-ke.com"
  config.hosts << "*.carboncube-ke.com"
  config.hosts << "backend"
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
  # Removed IP address to prevent search engines from indexing it
  config.hosts << "carbon-frontend-1"
  config.hosts << "carbon-backend-1"
  # config.hosts.clear # Allow all hosts (only for debugging)

  # Skip DNS rebinding protection for the default health check endpoint.
  # Allow requests from frontend container and external domains
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  config.hosts << "carbon-frontend-1"
  config.hosts << "carbon-backend-1"

  # Use a different cache store in production.
  # Use file store if Redis is not available, otherwise use Redis
  if ENV['REDIS_URL'].present?
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL']
    }
  else
    config.cache_store = :file_store, Rails.root.join("tmp", "cache")
  end

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp-relay.brevo.com',
    port: 587,  # Use port 587 with STARTTLS (port 465 is blocked)
    domain: 'carboncube-ke.com',
    user_name: ENV['BREVO_SMTP_USER'],
    password: ENV['BREVO_SMTP_PASSWORD'],
    authentication: :plain,
    ssl: false,  # Use STARTTLS instead of direct SSL
    tls: true,
    enable_starttls_auto: true,
    openssl_verify_mode: OpenSSL::SSL::VERIFY_PEER  # Proper certificate verification in production
  }

  config.action_mailer.default_options = {
    from: ENV['BREVO_EMAIL'],
    reply_to: ENV['BREVO_EMAIL']
  }
  
  # Set default URL options for email links
  config.action_mailer.default_url_options = {
    host: 'carboncube-ke.com',
    protocol: 'https'
  }
  
  # Enable email delivery in production
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
end
