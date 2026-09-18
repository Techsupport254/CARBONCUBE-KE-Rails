# frozen_string_literal: true

# Hourly sweep of pending partner invites:
#   - sends reminder 1 (T+2d, gentle) and reminder 2 (T+5d, expiry warning),
#     each with distinct copy, over email + WhatsApp
#   - flips invites past expiry to `expired` and alerts the internal team so
#     a human can call or re-invite (no more automated messages after that)
# Every send re-checks pending? so reminders never fire after acceptance.
class PartnerInviteReminderJob < ApplicationJob
  queue_as :low

  def perform
    PartnerInvite.due_for_reminder.find_each do |invite|
      stage = invite.reminder_stage_due
      next unless stage

      send_reminder(invite, stage)
      invite.mark_reminded!
    rescue StandardError => e
      Rails.logger.error "[PartnerInviteReminderJob] reminder failed for invite #{invite.id}: #{e.message}"
    end

    PartnerInvite.past_expiry.find_each do |invite|
      invite.expire!
      notify_expired(invite)
    rescue StandardError => e
      Rails.logger.error "[PartnerInviteReminderJob] expiry handling failed for invite #{invite.id}: #{e.message}"
    end
  end

  private

  def send_reminder(invite, stage)
    return unless invite.pending?

    PartnerInviteMailer.reminder(invite, stage).deliver_now if invite.email.present?
    if invite.phone.present?
      WhatsAppCloudService.send_template_or_text(
        invite.phone,
        **PartnerInviteCopy.reminder_template(invite, stage),
        fallback_text: PartnerInviteCopy.reminder(invite, stage)
      )
    end
  end

  def notify_expired(invite)
    PartnerInviteMailer.expired_internal(invite).deliver_now
    WhatsAppCloudService.send_template_or_text(
      PartnerInviteCopy.internal_whatsapp_number,
      **PartnerInviteCopy.expired_internal_template(invite),
      fallback_text: PartnerInviteCopy.expired_internal(invite)
    )
  end
end
