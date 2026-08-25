# Flushes hourly field location pings from Redis to PostgreSQL.
#
# Triggered daily by sidekiq-cron at 5:00 PM EAT (14:00 UTC) — after the
# 8am-4pm work window closes. For each user who pinged today, creates or
# updates a single SalesUserFieldLocation row with:
#   - The first ping's data as the "primary" location (lat, lng, display_name, etc.)
#   - All pings stored in the JSONB `pings` column
#
# If the job fails, Redis keys have a 2-day TTL so data survives a retry
# the next day. The job can also be run manually for a specific date.
class SyncFieldLocationsJob < ApplicationJob
  queue_as :low

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(date = FieldLocationRedisService.eat_today)
    Rails.logger.info "Starting field location sync from Redis to PostgreSQL for #{date}"

    pending = FieldLocationRedisService.pending_keys(date)
    Rails.logger.info "Found #{pending.size} pending field location keys"

    flushed = 0
    pending.each do |entry|
      pings = FieldLocationRedisService.fetch_pings(entry[:user_id], entry[:date])
      next if pings.empty?

      # Use the first ping of the day as the "primary" location
      first = pings.first
      check_in_date = Date.parse(entry[:date])

      # Upsert: find or initialize by user + date, then update
      record = SalesUserFieldLocation.find_or_initialize_by(
        sales_user_id: entry[:user_id],
        check_in_date: check_in_date
      )

      record.assign_attributes(
        latitude: first['lat'],
        longitude: first['lng'],
        display_name: first['display_name'],
        address: first['address'] || {},
        area: first['area'],
        city: first['city'],
        county: first['county'],
        country: first['country'],
        notes: first['notes'],
        pings: pings
      )

      if record.save
        FieldLocationRedisService.delete_key(entry[:key])
        flushed += 1
      else
        Rails.logger.error "Failed to save field location for user #{entry[:user_id]}: #{record.errors.full_messages.join(', ')}"
      end
    end

    Rails.logger.info "Field location sync completed: #{flushed}/#{pending.size} records flushed"
  end
end
