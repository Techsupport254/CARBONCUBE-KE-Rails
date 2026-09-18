# frozen_string_literal: true

# Partner self-service: the linked seller sees and maintains their own
# partnership profile. Partners own contact/branding fields; staff-owned
# fields (status, commission, agreement) are read-only here.
class Seller::PartnerProfilesController < ApplicationController
  include PartnerLogoUploadable

  before_action :authenticate_seller
  before_action :set_partner

  # GET /seller/partner_profile
  def show
    render json: {
      partner: PartnerPresenter.partner(@partner),
      contacts: @partner.contacts.map { |c| PartnerPresenter.contact(c) },
      recent_updates: @partner.updates.limit(10).map { |u| PartnerPresenter.update(u) }
    }
  end

  # PATCH /seller/partner_profile — accepts JSON, or multipart when a new
  # logo file rides along (field: logo), matching the profile-picture flow.
  def update
    logo = partner_logo_attrs
    if logo == :error
      return render json: { error: PartnerLogoUploadable::LOGO_ERROR }, status: :unprocessable_entity
    end

    if @partner.update(partner_owned_params.merge(logo))
      render json: { partner: PartnerPresenter.partner(@partner.reload) }
    else
      render json: { error: @partner.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  def set_partner
    @partner = @current_seller&.partner
    return if @partner

    render json: { error: 'No partner relationship linked to this account' }, status: :not_found
  end

  # Fields a partner may edit themselves — staff own status, commission, terms.
  def partner_owned_params
    params.permit(:contact_person, :phone, :email, :website, :location, :logo_url, :description)
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
