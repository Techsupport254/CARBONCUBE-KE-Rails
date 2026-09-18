# frozen_string_literal: true

# Partner-invite lifecycle mailer — every stage has distinct copy:
#   invite:           the initial join link
#   reminder:         stage 1 (gentle nudge) and stage 2 (expiry warning)
#   joined_internal:  team alert when an invitee accepts
#   expired_internal: team alert when an invite lapses (someone should call)
class PartnerInviteMailer < ApplicationMailer
  default from: "Carbon Cube Kenya <#{ENV['BREVO_EMAIL']}>"

  INTERNAL_EMAIL = -> { ENV['ADMIN_EMAIL'].presence || ENV['BREVO_EMAIL'] }

  def invite(invite)
    @invite = invite
    return unless invite.email.present?

    mail(
      to: invite.email,
      bcc: ENV['BREVO_EMAIL'],
      subject: invite.invite_kind == 'existing_account' ?
        "You've been invited to partner with Carbon Cube Kenya" :
        "Your Carbon Cube Kenya #{role_label(invite)} account is ready",
      react: react_props(stage: 'invite')
    )
  end

  def reminder(invite, stage)
    @invite = invite
    return unless invite.email.present?

    mail(
      to: invite.email,
      bcc: ENV['BREVO_EMAIL'],
      subject: stage == 2 ?
        "Final reminder — your Carbon Cube invite expires soon" :
        "Reminder — complete your Carbon Cube #{role_label(invite)} setup",
      react: react_props(stage: "reminder_#{stage}")
    )
  end

  # Team notification: invitee accepted and their access is live.
  def joined_internal(invite)
    recipient = INTERNAL_EMAIL.call
    return unless recipient.present?

    @invite = invite
    mail(
      to: recipient,
      bcc: ENV['BREVO_EMAIL'],
      subject: "#{invitee_name(invite)} joined as #{role_label(invite)}",
      react: react_props(stage: 'joined_internal')
    )
  end

  # Team notification: invite expired unaccepted — follow up by phone.
  def expired_internal(invite)
    recipient = INTERNAL_EMAIL.call
    return unless recipient.present?

    @invite = invite
    mail(
      to: recipient,
      bcc: ENV['BREVO_EMAIL'],
      subject: "Invite expired — #{invitee_name(invite)} never joined",
      react: react_props(stage: 'expired_internal')
    )
  end

  private

  def invitee_name(invite)
    invite.invitee.try(:name).presence || invite.email.presence || 'A partner'
  end

  def role_label(invite)
    case invite.invitee_type
    when 'PartnerDistributor' then 'distributor'
    when 'PartnerContact' then 'contact'
    else 'partner'
    end
  end

  def partner_name(invite)
    case invite.invitee
    when Partner then invite.invitee.name
    when PartnerDistributor, PartnerContact then invite.invitee.partner&.name
    end
  end

  def react_props(stage:)
    {
      stage: stage,
      invite_kind: @invite.invite_kind,
      role_label: role_label(@invite),
      invitee_name: invitee_name(@invite),
      partner_name: partner_name(@invite),
      join_url: @invite.join_url,
      expires_at: @invite.expires_at&.strftime('%B %d, %Y'),
      invited_by: @invite.invited_by.try(:fullname) || @invite.invited_by.try(:email),
      accepted_at: @invite.accepted_at&.strftime('%B %d, %Y at %I:%M %p'),
      seller_name: @invite.seller&.enterprise_name || @invite.seller&.fullname,
      benefits: PartnerBenefits.markdown(@invite.invitee),
      benefits_heading: PartnerBenefits.heading(@invite.invitee),
      support_email: ENV['BREVO_EMAIL'] || 'support@carboncube.co.ke',
      support_phone: '+254 712 990 524'
    }
  end
end
