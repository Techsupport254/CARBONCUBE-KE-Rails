require "active_support/core_ext/integer/time"

# Custom logger class for Rails 7.1.5.2 compatibility
# Logs to both file and STDOUT, but filters out request logs ("Started GET", etc.)
class DualLogger < ActiveSupport::Logger
  def initialize(*args)
    super
    @stdout_logger = ActiveSupport::Logger.new(STDOUT)
    @stdout_logger.formatter = formatter
    @stdout_logger.level = level
  end

  def add(severity, message = nil, progname = nil, &block)
    # Get the actual message string
    msg = message || (block && block.call) || progname
    
    # Convert to string for matching
    msg_str = msg.to_s
    
    # Filter out request logs and serializer logs
    # Filter "Started GET/POST" request logs
    if msg_str.match?(/^Started (GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)/i) || msg_str.match?(/^Processing by/i)
      super # Log to file only
      return self
    end
    
    # Filter ActiveModel Serializer rendering logs (comprehensive pattern)
    if msg_str.match?(/Rendered ActiveModel::Serializer/i) || 
       msg_str.match?(/ActiveModelSerializers/i) ||
       msg_str.match?(/ActiveModel::Serializer/i) ||
       msg_str.match?(/Serializer.*Adapter/i)
      super # Log to file only
      return self
    end
    
    super
    @stdout_logger.add(severity, message, progname, &block)
  end
end

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  # 
  config.hosts << "localhost"
  config.hosts << "127.0.0.1"
  config.hosts << "carboncube-ke.com/api"
  
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
  # Log to both STDOUT and file for easier monitoring
  log_file = Rails.root.join('log', 'development.log')
  log_file_dir = File.dirname(log_file)
  FileUtils.mkdir_p(log_file_dir) unless File.directory?(log_file_dir)
  
  # Create a logger that writes to both STDOUT and file
  # For Rails 7.1.5.2 compatibility, use a custom logger class
  log_device = File.open(log_file, 'a')
  log_device.sync = true # Flush immediately
  
  config.logger = DualLogger.new(log_device)
  config.log_level = :debug
  
  # Suppress ActionController request/response logging ("Started GET", etc.)
  # and configure ActionCable logging
  config.after_initialize do
    # Suppress ActionController::LogSubscriber which logs "Started GET" messages
    if defined?(ActionController::LogSubscriber)
      ActiveSupport::Notifications.unsubscribe ActionController::LogSubscriber
      ActionController::LogSubscriber.logger = Logger.new(File::NULL)
    end
    
    # Suppress ActiveModel::Serializers logging
    if defined?(ActiveModel::Serializer)
      # Try to disable ActiveModel Serializers logging if possible
      begin
        ActiveModelSerializers.logger = Logger.new(File::NULL) if defined?(ActiveModelSerializers)
      rescue => e
        # Ignore if logger cannot be set
      end
    end
    
    # Configure ActionCable logging
    ActionCable.server.config.logger = Logger.new(STDOUT)
    ActionCable.server.config.logger.level = Logger::WARN
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
  # Try port 465 with SSL first, fallback to 587 with STARTTLS
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp-relay.brevo.com',
    port: 465,  # SSL port (alternative to 587 with STARTTLS)
    domain: 'carboncube-ke.com',
    user_name: ENV['BREVO_SMTP_USER'],
    password: ENV['BREVO_SMTP_PASSWORD'],
    authentication: :plain,
    ssl: true,  # Use direct SSL connection
    tls: false,
    enable_starttls_auto: false,
    openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
  }

  config.action_mailer.default_options = {
    from: ENV['BREVO_EMAIL'],
    reply_to: ENV['BREVO_EMAIL']
  }
  
  # Enable detailed SMTP logging
  config.action_mailer.logger = Rails.logger
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  
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

  # Suppress ActiveModel Serializer logging
  config.after_initialize do
    if defined?(ActiveModelSerializers)
      ActiveModelSerializers.logger = Logger.new(File::NULL)
    end
  end

end
