# frozen_string_literal: true

# Partner self-service: a partner manages its own distribution network —
# the resellers/buyers who get onboarded via PartnerInvite and subscribed to
# pricing + announcement updates. Mirrors the staff-side
# Sales::PartnerDistributorsController but scoped to the seller's own partner.
class Seller::PartnerDistributorsController < ApplicationController
  include PartnerLogoUploadable

  before_action :authenticate_seller
  before_action :set_partner
  before_action :set_distributor, only: %i[update destroy resend_invite]

  # GET /seller/partner_profile/distributors
  def index
    render json: {
      distributors: @partner.distributors.includes(:seller).map { |d| serialize(d) }
    }
  end

  # POST /seller/partner_profile/distributors
  # Adds a network member and, when an email is on file, immediately issues
  # the onboarding invite so they land on the join page right away.
  def create
    existing = find_duplicate_distributor
    if existing
      return render json: { success: true, existing: true, distributor: serialize(existing) }
    end

    logo = partner_logo_attrs
    if logo == :error
      return render json: { error: PartnerLogoUploadable::LOGO_ERROR }, status: :unprocessable_entity
    end

    distributor = @partner.distributors.new(
      distributor_params.merge(logo).merge(
        actor_name: @current_seller.enterprise_name.presence || @current_seller.fullname
      )
    )
    distributor.seller_id = distributor.matching_seller&.id
    distributor.status = distributor.seller_id.present? ? 'active' : 'invited'

    unless distributor.save
      return render json: { error: distributor.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end

    invite, invite_error = issue_invite(distributor)
    render json: {
      success: true,
      distributor: serialize(distributor.reload),
      invite: serialize_invite(invite),
      invite_error: invite_error
    }, status: :created
  end

  # PATCH /seller/partner_profile/distributors/:id
  def update
    logo = partner_logo_attrs
    if logo == :error
      return render json: { error: PartnerLogoUploadable::LOGO_ERROR }, status: :unprocessable_entity
    end

    if @distributor.update(distributor_params.merge(logo))
      render json: { distributor: serialize(@distributor) }
    else
      render json: { error: @distributor.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # DELETE /seller/partner_profile/distributors/:id
  def destroy
    @distributor.destroy
    render json: { success: true }
  end

  # POST /seller/partner_profile/distributors/:id/resend_invite
  def resend_invite
    pending = @distributor.pending_invite
    return render json: { error: 'No pending invite to resend' }, status: :unprocessable_entity unless pending

    invite = pending.resend!(invited_by: @current_seller)
    PartnerInviteJob.perform_later(invite.id)
    render json: { success: true, invite: serialize_invite(invite) }
  end

  private

  def distributor_params
    permitted = params.permit(:name, :contact_person, :phone, :email, :location, :notes,
                              :territory, :business_type, :website, :logo_url,
                              :notify_pricing, :notify_updates)
    # Status is partner-managed on update only — create derives it from matching.
    permitted[:status] = params[:status] if action_name == 'update' &&
                                          %w[invited active inactive].include?(params[:status])
    permitted
  end

  # Issue + queue the join invite when there's an email to send to.
  # Returns [invite, error_message] — never raises so create still succeeds.
  def issue_invite(distributor)
    return [nil, 'Add an email to send them a join invite'] if distributor.email.blank?

    invite = PartnerInviteIssuer.call(distributor, actor: @current_seller,
                                                   email: distributor.email,
                                                   phone: distributor.phone)
    PartnerInviteJob.perform_later(invite.id)
    [invite, nil]
  rescue PartnerInviteIssuer::Error, ActiveRecord::RecordInvalid => e
    [nil, e.respond_to?(:record) ? e.record.errors.full_messages.join(', ') : e.message]
  end

  def set_partner
    @partner = @current_seller&.partner
    return if @partner

    render json: { error: 'No partner relationship linked to this account' }, status: :not_found
  end

  def set_distributor
    @distributor = @partner.distributors.find_by(id: params[:id])
    render json: { error: 'Distributor not found' }, status: :not_found unless @distributor
  end

  def find_duplicate_distributor
    if params[:phone].present?
      digits = params[:phone].to_s.gsub(/\D/, '')
      if digits.length >= 9
        suffix = digits[-9..]
        match = @partner.distributors.where('phone LIKE ?', "%#{suffix}").first
        return match if match
      end
    end

    return nil if params[:name].blank?

    @partner.distributors.where('LOWER(name) = ?', params[:name].to_s.strip.downcase).first
  end

  def serialize_invite(invite)
    return nil unless invite

    {
      id: invite.id,
      status: invite.status,
      invite_kind: invite.invite_kind,
      expires_at: invite.expires_at,
      join_url: invite.join_url
    }
  end

  def serialize(distributor)
    {
      id: distributor.id,
      name: distributor.name,
      contact_person: distributor.contact_person,
      phone: distributor.phone,
      email: distributor.email,
      location: distributor.location,
      territory: distributor.territory,
      business_type: distributor.business_type,
      website: distributor.website,
      logo_url: distributor.logo_url,
      notes: distributor.notes,
      status: distributor.status,
      notify_pricing: distributor.notify_pricing,
      notify_updates: distributor.notify_updates,
      seller_name: distributor.seller&.enterprise_name || distributor.seller&.fullname,
      seller_slug: distributor.seller&.url_slug,
      pending_invite: serialize_invite(distributor.pending_invite),
      created_at: distributor.created_at
    }
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
