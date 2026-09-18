# frozen_string_literal: true

# Delivers a partner invite over email and WhatsApp, then stamps
# invite_sent_at so the reminder schedule can measure from send time.
class PartnerInviteJob < ApplicationJob
  queue_as :default

  def perform(invite_id)
    invite = PartnerInvite.find_by(id: invite_id)
    return unless invite&.pending?

    PartnerInviteMailer.invite(invite).deliver_now if invite.email.present?
    if invite.phone.present?
      WhatsAppCloudService.send_template_or_text(
        invite.phone,
        **PartnerInviteCopy.invite_template(invite),
        fallback_text: PartnerInviteCopy.invite(invite)
      )
    end
    invite.mark_invite_sent!
  end
end
