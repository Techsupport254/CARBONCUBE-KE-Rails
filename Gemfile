source "https://rubygems.org"


# Specify your gem's dependencies in backend/Gemfile
ruby "3.4.4" 

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails" , "~> 8.0.2"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem 'pg'

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# JWT authentication
gem 'jwt'

# Authentication
gem 'bcrypt', '~> 3.1.7'  # for password hashing

# CORS
gem 'rack-cors', require: 'rack/cors'

# YAML
gem 'psych', '~> 5.1.0'

# Rubyzip
gem 'rubyzip', '~> 2.3.2'


# # Sinatra
# gem "sinatra", '~> 4.0.0'
# gem "sinatra-activerecord", '~> 2.0.27'

# serializers
gem 'active_model_serializers'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "vips"
gem "image_processing", "~> 1.12"

# Password manager env
gem 'dotenv-rails', groups: [:development, :test, :production]

# Gem fot httparty requests
gem 'httparty'

# Search on postgresql
gem 'pg_search'

# Date grouping gem
gem 'groupdate'

# Seed generator
gem 'faker'

# Redis
gem 'redis'

# Parallel for image processing
gem 'parallel'

# Use hiredis to get better performance than the "redis" gem
gem 'hiredis'

# Amazon Rekognition for image moderation
# gem 'aws-sdk-rekognition', '~> 1.111'
# 
# Cron Job Gem
gem 'whenever', require: false


# Cloudinary for image hosting
gem 'cloudinary'

# Use the sitemap generator for SEO
gem 'sitemap_generator'


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
