# config/schedule.rb

set :output, "/root/CARBON/log/cron.log"  # Or change to a path inside your Rails backend container, if preferred
env :PATH, ENV['PATH']

every 1.day, at: '12:00 am' do
  command "cd /root/CARBON && docker-compose exec -T backend rake documents:send_reminders"
end

# Precompute best sellers every 30 minutes for instant loading
every 30.minutes do
  command "cd /root/CARBON && docker-compose exec -T backend rails runner 'PrecomputeBestSellersJob.perform_now'"
end
