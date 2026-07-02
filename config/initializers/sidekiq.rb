# config/initializers/sidekiq.rb
require 'sidekiq'
require 'sidekiq-cron'

redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url, size: 25 }

  # Load recurring job schedule from config/schedule.yml.
  # Only runs inside the Sidekiq server process — never in web/console.
  schedule_file = Rails.root.join('config', 'schedule.yml')
  if File.exist?(schedule_file)
    schedule = YAML.load_file(schedule_file)
    Sidekiq::Cron::Job.load_from_hash(schedule)
    Rails.logger.info "[Sidekiq] Loaded #{schedule.keys.size} cron jobs from config/schedule.yml"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url, size: 5 }
end

# Use Sidekiq as the Active Job adapter in all environments.
Rails.application.configure do
  config.active_job.queue_adapter = :sidekiq

  # Map Rails Active Job queue names to Sidekiq queues.
  # Jobs that don't declare queue_as will land in :default.
  config.active_job.default_queue_name = :default

  config.websocket_enabled = true
end
