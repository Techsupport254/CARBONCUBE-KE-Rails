require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Mjml
  def self.valid_mjml_binary
    true
  end
  def self.check_for_custom_mjml_binary
    true
  end
end

module CarbonecomRails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`.
    config.autoload_lib(ignore: %w(assets tasks scripts))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    config.api_only = true
    
    # Sessions are not needed for API-only apps with JWT authentication
    # OAuth flow uses redirects with tokens, not sessions
    
    # Enable Action Cable for API-only Rails app
    config.action_cable.disable_request_forgery_protection = true
    config.action_cable.mount_path = '/cable'
    
    # Action Cable configuration
    config.action_cable.url = 'ws://localhost:3001/cable'
    config.action_cable.allowed_request_origins = ['http://localhost:3000', 'https://localhost:3000']
    config.action_cable.logger = Rails.logger
    
    # WebSocket fallback configuration
    config.websocket_enabled = ENV.fetch('WEBSOCKET_ENABLED', 'true') == 'true'
    
    # Background job configuration
    config.active_job.queue_adapter = :sidekiq
    
    # Time zone
    config.time_zone = 'UTC'
    
    # Security headers
    config.force_ssl = Rails.env.production?

    # Active Record Encryption for message content at rest
    base_secret = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] || ENV['SECRET_KEY_BASE'] || 'cc_enc_d85f543161caeaee2ef04ca51cf434e3415c8980bcf2e2ff62ddfe31c8adad6d'
    config.active_record.encryption.primary_key = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] || Digest::SHA256.hexdigest("#{base_secret}_primary")[0..31]
    config.active_record.encryption.deterministic_key = ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'] || Digest::SHA256.hexdigest("#{base_secret}_deterministic")[0..31]
    config.active_record.encryption.key_derivation_salt = ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT'] || Digest::SHA256.hexdigest("#{base_secret}_salt")[0..31]
    config.active_record.encryption.support_unencrypted_data = true
    
    # Database connection pooling configuration
    # Note: Connection pool settings are configured in database.yml
    
    # Add connection pool middleware
    # require_relative '../app/middleware/connection_pool_middleware'
    # config.middleware.use ConnectionPoolMiddleware

    # Strip trailing dots from URL paths to prevent RoutingError on slug URLs
    require_relative '../lib/middleware/strip_trailing_dot'
    config.middleware.insert_before Rack::Runtime, Middleware::StripTrailingDot
  end
end