# config/initializers/trigger_phone_campaign_on_deploy.rb
# Automatically enqueues the Phone Update Campaign job on application deployment boot.
# Protected by Redis idempotency locks so it only enqueues once per deployment/campaign cycle.

if defined?(Sidekiq) && Sidekiq.server?
  Rails.application.config.after_initialize do
    begin
      deploy_key = "deploy_hook:phone_update_campaign:#{Date.current}"
      
      # Use Redis lock to ensure it only triggers once per day on deploy boot
      should_trigger = Sidekiq.redis { |r| r.set(deploy_key, '1', nx: true, ex: 86400) }
      
      if should_trigger
        Rails.logger.info "[DeployHook] Triggering Phone Update Campaign for missing seller phone numbers..."
        SendPhoneUpdateReminderJob.perform_later(false, 1)
      end
    rescue => e
      Rails.logger.warn "[DeployHook] Phone update campaign deployment trigger warning: #{e.message}"
    end
  end
end
