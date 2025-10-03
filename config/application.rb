require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CarbonecomRails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # CORS configuration
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins 'https://carboncube-ke.vercel.app', 'http://localhost:3000', '*' # Adjust the origin as needed
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ['Authorization'] # If you need to expose Authorization header
      end
    end

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
    
    # Database connection pooling configuration
    # Note: Connection pool settings are configured in database.yml
    
    # Add connection pool middleware
    # require_relative '../app/middleware/connection_pool_middleware'
    # config.middleware.use ConnectionPoolMiddleware
  end
end