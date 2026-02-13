source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.4"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.0"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use Puma as the app server
gem "puma", ">= 5.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Load environment variables from .env files
gem "dotenv-rails"

# Google Authentication for Merchant API
gem "googleauth"
gem "google-apis-content_v2_1"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Redis for Action Cable in production
gem 'redis', '~> 5.0'
gem 'connection_pool', '~> 2.4'

# AnyCable for high-performance WebSockets
# gem 'anycable-rails', '~> 1.4'

# PgSearch for full-text search
gem 'pg_search'

# Active Model Serializers for JSON API responses
gem 'active_model_serializers'

# Additional gems based on your project
gem 'cloudinary'
gem 'activestorage-cloudinary-service'

# Sidekiq for background jobs
gem 'sidekiq'

# Markdown processing
gem 'redcarpet'

# Use Active Model has_secure_password
gem 'bcrypt', '~> 3.1.7'

# JWT for token authentication
gem 'jwt'

# HTTP client for API requests
gem 'httparty'

# Google APIs for OAuth
gem 'google-apis-oauth2_v2'

# Dry validation for form validation
gem 'dry-validation'

# User agent parser for better browser/OS/device detection
gem 'user_agent_parser'

# Image processing for generating personalized welcome images
gem 'mini_magick'
# QR code generation for welcome images
gem 'rqrcode'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
gem "mjml-rails", "~> 4.16"
