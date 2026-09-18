# frozen_string_literal: true

# Public join/accept endpoints for partner invites — no staff auth.
#
# GET  /partner_invites/:token → details for the join page (masked targets)
# POST /partner_invites/accept → consumes the token:
#   new_account:      sets the shell seller's password, issues a seller JWT
#   existing_account: requires the invited seller's session (Authorization header)
#   contact_confirm:  plain acknowledgement — no account involved
class PartnerInvitesController < ApplicationController
  # GET /partner_invites/:token
  def show
    invite = PartnerInvite.with_token(params[:token])
    return render_not_found unless invite

    render json: {
      status: invite.status,
      usable: invite.usable?,
      invite_kind: invite.invite_kind,
      invitee_type: invite.invitee_type,
      invitee_name: invitee_name(invite),
      partner_name: partner_name(invite),
      partner_logo_url: partner_logo_url(invite),
      benefits: PartnerBenefits.for_invitee(invite.invitee),
      email: mask_email(invite.email),
      phone: mask_phone(invite.phone),
      expires_at: invite.expires_at,
      requires_password: invite.invite_kind == 'new_account',
      requires_login: invite.invite_kind == 'existing_account'
    }
  end

  # POST /partner_invites/accept
  def accept
    invite = PartnerInvite.with_token(params[:token])
    return render_not_found unless invite

    unless invite.usable?
      reason = invite.accepted? ? 'This invite has already been accepted' : 'This invite has expired'
      return render json: { error: reason, status: invite.status }, status: :unprocessable_entity
    end

    acting_seller = optional_seller_session
    if invite.invite_kind == 'existing_account' && acting_seller.nil?
      return render json: { error: 'Please sign in to your seller account to accept this partnership',
                            requires_login: true }, status: :unauthorized
    end

    begin
      seller = invite.accept!(
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        acting_seller: acting_seller
      )
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end

    PartnerJoinedNotificationJob.perform_later(invite.id)

    render json: acceptance_payload(invite, seller)
  end

  private

  def acceptance_payload(invite, seller)
    payload = {
      success: true,
      status: invite.status,
      invite_kind: invite.invite_kind,
      invitee_name: invitee_name(invite),
      partner_name: partner_name(invite)
    }

    if seller
      payload[:token] = JsonWebToken.encode(seller_id: seller.id, email: seller.email, role: 'Seller')
      payload[:user] = SellerSerializer.new(seller).as_json
    end

    payload
  end

  # A seller session is optional here — present only for existing_account invites.
  def optional_seller_session
    seller = SellerAuthorizeApiRequest.new(request.headers).result
    seller.is_a?(Seller) ? seller : nil
  rescue StandardError
    nil
  end

  def invitee_name(invite)
    case invite.invitee
    when Partner then invite.invitee.name
    when PartnerDistributor then invite.invitee.name
    when PartnerContact then invite.invitee.name
    else invite.invitee.try(:name)
    end
  end

  def partner_name(invite)
    case invite.invitee
    when Partner then invite.invitee.name
    when PartnerDistributor, PartnerContact then invite.invitee.partner&.name
    end
  end

  # The business partner's logo — for distributors/contacts that's their
  # parent partner's mark, not their own.
  def partner_logo_url(invite)
    partner =
      case invite.invitee
      when Partner then invite.invitee
      when PartnerDistributor, PartnerContact then invite.invitee.partner
      end
    partner&.logo_url
  end

  def mask_email(email)
    return nil if email.blank?

    name, domain = email.split('@')
    return email if domain.blank?

    masked = name.length > 2 ? "#{name[0]}***#{name[-1]}" : "#{name[0]}***"
    "#{masked}@#{domain}"
  end

  def mask_phone(phone)
    return nil if phone.blank?

    clean = phone.to_s.strip
    return clean if clean.length < 5

    "#{clean[0..3]}****#{clean[-2..]}"
  end

  def render_not_found
    render json: { error: 'Invite not found or link is invalid' }, status: :not_found
  end
end
