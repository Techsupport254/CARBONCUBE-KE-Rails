require_relative "boot"
require "rails/all"

# Load environment variables from .env in development and test environments
if ['development', 'test'].include?(ENV['RAILS_ENV'] || ENV['RACK_ENV'])
  require 'dotenv'
  Dotenv.load('.env')
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CARBONCUBE_KERails
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Add this line:
    config.middleware.use Rack::ContentLength

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = 'Africa/Nairobi' # Example for EAT time zone
    config.active_record.default_timezone = :local
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Pilot phase configuration - can be disabled in production
    # Set PILOT_PHASE_ENABLED=false in production environment to disable pilot restrictions
    config.pilot_phase_enabled = ENV.fetch('PILOT_PHASE_ENABLED', 'true').downcase == 'true'
    
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
    
    # Enable ActionCable for API-only applications
    config.action_cable.mount_path = '/cable'
    config.action_cable.allowed_request_origins = ['http://localhost:3000', 'https://carboncube-ke.vercel.app']
    
    # Fix ActionCable logger issue
    config.after_initialize do
      ActionCable.server.config.logger = Rails.logger
      ActionCable.server.config.log_tags = []
    end
  end
end
