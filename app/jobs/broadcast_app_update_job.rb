# frozen_string_literal: true

# Broadcasts a one-off "what's new" announcement to every buyer and seller:
#   - persists an in-app Notification row for each user
#   - sends an FCM push when the user has registered device tokens
#
# Idempotent: users that already received this broadcast (matched by title)
# are skipped on re-runs. Triggered via `rake broadcast:app_update[dry_run]`.
class BroadcastAppUpdateJob < ApplicationJob
  queue_as :broadcast

  TITLE = 'New App Update: Version 1.0.7'
  BODY  = "We've made Carbon Cube better - sellers can now review products and shops, " \
          'ads publish automatically in the background, and your shop gets a new QR ' \
          'Studio. Update to the latest version to try it all!'
  DATA  = { 'type' => 'app_update', 'version' => '1.0.7' }.freeze

  def perform(dry_run: true)
    stats = { eligible: 0, notified: 0, pushed: 0, skipped_duplicate: 0, failed: 0 }

    [Buyer, Seller, SalesUser].each do |klass|
      klass.find_each do |user|
        stats[:eligible] += 1

        if Notification.exists?(recipient: user, title: TITLE)
          stats[:skipped_duplicate] += 1
          next
        end
        next if dry_run

        notify(user, stats)
        stats[:notified] += 1
      rescue StandardError => e
        stats[:failed] += 1
        Rails.logger.error "[BroadcastAppUpdateJob] #{klass.name}##{user.id} failed: #{e.message}"
      end
    end

    stats
  end

  private

  def notify(user, stats)
    tokens = DeviceToken.where(user: user).pluck(:token)

    if tokens.any?
      # The service persists a Notification row for the user itself
      PushNotificationService.send_notification(tokens, payload)
      stats[:pushed] += 1
    else
      Notification.create!(recipient: user, title: TITLE, body: BODY, data: DATA)
    end
  end

  def payload
    { title: TITLE, body: BODY, data: DATA }
  end
end
