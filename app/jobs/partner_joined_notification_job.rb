# frozen_string_literal: true

# Internal alert when an invitee accepts: email to ADMIN_EMAIL and a
# WhatsApp to the internal number so the team knows the partner is live.
class PartnerJoinedNotificationJob < ApplicationJob
  queue_as :default

  def perform(invite_id)
    invite = PartnerInvite.find_by(id: invite_id)
    return unless invite

    PartnerInviteMailer.joined_internal(invite).deliver_now
    WhatsAppCloudService.send_template_or_text(
      PartnerInviteCopy.internal_whatsapp_number,
      **PartnerInviteCopy.joined_internal_template(invite),
      fallback_text: PartnerInviteCopy.joined_internal(invite)
    )
  end
end
