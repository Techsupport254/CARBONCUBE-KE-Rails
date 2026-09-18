# frozen_string_literal: true

# Partner self-service: manage contacts on their own partner record.
class Seller::PartnerContactsController < ApplicationController
  before_action :authenticate_seller
  before_action :set_partner
  before_action :set_contact, only: %i[update destroy]

  # GET /seller/partner_profile/contacts
  def index
    render json: { contacts: @partner.contacts.map { |c| PartnerPresenter.contact(c) } }
  end

  # POST /seller/partner_profile/contacts
  def create
    contact = @partner.contacts.new(contact_params)
    if contact.save
      render json: { contact: PartnerPresenter.contact(contact) }, status: :created
    else
      render json: { error: contact.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # PATCH /seller/partner_profile/contacts/:id
  def update
    if @contact.update(contact_params)
      render json: { contact: PartnerPresenter.contact(@contact) }
    else
      render json: { error: @contact.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  # DELETE /seller/partner_profile/contacts/:id
  def destroy
    @contact.destroy
    render json: { success: true }
  end

  private

  def set_partner
    @partner = @current_seller&.partner
    return if @partner

    render json: { error: 'No partner relationship linked to this account' }, status: :not_found
  end

  def set_contact
    @contact = @partner.contacts.find_by(id: params[:id])
    render json: { error: 'Contact not found' }, status: :not_found unless @contact
  end

  def contact_params
    params.permit(:name, :role_title, :email, :phone, :is_primary, :receives_updates, :notes)
  end

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    unless @current_seller.is_a?(Seller)
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
