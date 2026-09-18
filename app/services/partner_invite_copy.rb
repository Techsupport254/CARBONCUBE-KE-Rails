# frozen_string_literal: true

# Plain-text copy for partner-invite WhatsApp messages — one variant per
# lifecycle stage so each touch says something different (invite = welcome,
# reminder 1 = nudge, reminder 2 = expiry warning).
module PartnerInviteCopy
  module_function

  def role_label(invite)
    case invite.invitee_type
    when 'PartnerDistributor' then 'distributor'
    when 'PartnerContact' then 'contact'
    else 'partner'
    end
  end

  def invitee_name(invite)
    invite.invitee.try(:name).presence || 'there'
  end

  def partner_name(invite)
    case invite.invitee
    when Partner then invite.invitee.name
    when PartnerDistributor, PartnerContact then invite.invitee.partner&.name
    end
  end

  def expiry(invite)
    invite.expires_at&.strftime('%b %d')
  end

  def invite(invite)
    role = role_label(invite)
    context = partner_name(invite)
    context = context && role != 'partner' ? " (#{context})" : ''
    action =
      case invite.invite_kind
      when 'new_account' then 'Set your password to activate your seller account'
      when 'existing_account' then 'Accept the partnership on your seller account'
      else 'Confirm your details'
      end
    "Carbon Cube Kenya: you've been invited as a #{role}#{context}. " \
      "#{action}: #{invite.join_url} (expires #{expiry(invite)})" \
      "\n\nHere's what you get:\n#{PartnerBenefits.whatsapp_lines(invite.invitee)}"
  end

  def reminder(invite, stage)
    role = role_label(invite)
    if stage == 2
      "Carbon Cube Kenya: last reminder — your #{role} invite expires #{expiry(invite)}. " \
        "Join now: #{invite.join_url}"
    else
      "Carbon Cube Kenya: your #{role} invite is still waiting. " \
        "Finish setup: #{invite.join_url}" \
        "\n\nDon't miss out:\n#{PartnerBenefits.whatsapp_lines(invite.invitee, limit: 3)}"
    end
  end

  def joined_internal(invite)
    role = role_label(invite)
    context = partner_name(invite)
    context = context && role != 'partner' ? " for #{context}" : ''
    "#{invitee_name(invite)} joined as #{role}#{context} — invite accepted."
  end

  def expired_internal(invite)
    role = role_label(invite)
    "#{invitee_name(invite)}'s #{role} invite expired unaccepted — " \
      'reminders stopped. Call them or re-invite from the partners page.'
  end

  # --- Approved WhatsApp templates (Meta WABA) -----------------------------

  TEMPLATE_LANGUAGE = 'en'

  # Merged role + context for template variables — Meta requires every
  # parameter to be non-empty, so context can never be a standalone variable.
  def role_context(invite)
    case invite.invitee
    when PartnerDistributor then "distributor in #{partner_name(invite)}'s network"
    when PartnerContact then "contact for #{partner_name(invite)}"
    else 'partner'
    end
  end

  # Each benefit is its own template parameter — Meta forbids newlines inside
  # parameter values, so the approved templates carry one "• {{n}}" per line.
  def invite_template(invite)
    template_payload(
      'partner_invite_v1',
      [invitee_name(invite), role_context(invite),
       *PartnerBenefits.for_invitee(invite.invitee).first(4), expiry(invite)],
      join_token: invite.token
    )
  end

  def reminder_template(invite, stage)
    if stage == 2
      template_payload(
        'partner_invite_final_v1',
        [invitee_name(invite), role_context(invite), expiry(invite)],
        join_token: invite.token
      )
    else
      template_payload(
        'partner_invite_reminder_v1',
        [invitee_name(invite), role_context(invite),
         *PartnerBenefits.for_invitee(invite.invitee).first(3)],
        join_token: invite.token
      )
    end
  end

  def joined_internal_template(invite)
    template_payload('partner_joined_internal_v1', [invitee_name(invite), role_context(invite)])
  end

  def expired_internal_template(invite)
    template_payload('partner_invite_expired_v1', [invitee_name(invite), role_label(invite)])
  end

  # Meta rejects template parameters containing newlines, tabs, or runs of
  # more than 4 spaces (error #132018) — squish collapses all of these.
  def template_payload(name, body_params, join_token: nil)
    components = [{
      type: 'body',
      parameters: body_params.map { |value| { type: 'text', text: value.to_s.squish } }
    }]
    if join_token
      components << {
        type: 'button', sub_type: 'url', index: '0',
        parameters: [{ type: 'text', text: join_token }]
      }
    end
    { template_name: name, language: TEMPLATE_LANGUAGE, components: components }
  end

  def internal_whatsapp_number
    ENV['INTERNAL_WHATSAPP_NUMBER'].presence || '+254712990524'
  end
end
