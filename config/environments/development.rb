require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  # 
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
  
  # Set secret key base for development
  config.secret_key_base = 'development_secret_key_change_in_production_123456789012345678901234567890123456789012345678901234567890'

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true
  
  # Temporarily disable migration check for development
  config.active_record.migration_error = :page_load

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Configure Action Cable for development
  config.action_cable.url = 'ws://localhost:3001/cable'
  config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
  
  # Enable Action Cable in development
  config.action_cable.disable_request_forgery_protection = true
  
  # Disable force SSL in development
  config.force_ssl = false
  
  # Ensure proper logger configuration
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.log_level = :debug
  
  # Fix ActionCable logger issue - ensure logger exists
  config.after_initialize do
    ActionCable.server.config.logger = Rails.logger
    ActionCable.server.config.log_tags = []
  end
  
  # Ensure ActionCable is properly configured
  config.action_cable.disable_request_forgery_protection = true
  
  # Set mount path for ActionCable
  config.action_cable.mount_path = '/cable'
  
  # Configure worker pool size
  config.action_cable.worker_pool_size = 4

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.perform_caching = false

  # Configure SMTP for development
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp-relay.brevo.com',
    port: 587,  # Standard SMTP port with STARTTLS
    domain: 'carboncube-ke.com',
    user_name: ENV['BREVO_SMTP_USER'],
    password: ENV['BREVO_SMTP_PASSWORD'],
    authentication: :plain,
    enable_starttls_auto: true,  # Enable STARTTLS for secure connection
    openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE  # Skip certificate verification in development
  }

  config.action_mailer.default_options = {
    from: ENV['BREVO_EMAIL'],
    reply_to: ENV['BREVO_EMAIL']
  }
  
  # Enable detailed SMTP logging
  config.action_mailer.logger = Rails.logger
  config.action_mailer.perform_deliveries = true
  
  # Set default URL options for email links
  config.action_mailer.default_url_options = {
    host: 'localhost',
    port: 3000,
    protocol: 'http'
  }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = false

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = false

  # Assets are not used in API-only mode

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true

  # Reduce ActiveModel Serializer logging
  # config.active_model_serializers.logger = Logger.new(nil)

  # Reduce ActionCable logging to minimize noise
  config.after_initialize do
    ActionCable.server.config.logger = Logger.new(STDOUT)
    ActionCable.server.config.logger.level = Logger::WARN
    ActionCable.server.config.log_tags = []
  end
end
