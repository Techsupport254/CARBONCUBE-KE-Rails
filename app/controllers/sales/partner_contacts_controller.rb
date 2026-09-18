# frozen_string_literal: true

module Sales
  # Contacts at a partner organization — staff-side management. Partners can
  # also manage their own contacts via /seller/partner_contacts.
  class PartnerContactsController < ApplicationController
    include SalesOrAdminAuthenticatable

    before_action :authenticate_sales_or_admin
    before_action :set_partner
    before_action :set_contact, only: %i[update destroy invite]

    # GET /sales/partners/:partner_id/contacts
    def index
      render json: { data: @partner.contacts.map { |c| serialize_contact(c) } }
    end

    # POST /sales/partners/:partner_id/contacts
    def create
      contact = @partner.contacts.new(
        name: params[:name],
        role_title: params[:role_title].presence || params[:roleTitle].presence,
        email: params[:email].presence,
        phone: params[:phone].presence,
        is_primary: truthy?(params[:is_primary] || params[:isPrimary]),
        receives_updates: params.key?(:receives_updates) ? truthy?(params[:receives_updates]) : true,
        notes: params[:notes].presence
      )

      unless contact.save
        return render json: { error: contact.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      render json: { success: true, contact: serialize_contact(contact) }, status: :created
    end

    # PATCH /sales/partners/:partner_id/contacts/:id
    def update
      update_attrs = {}
      %i[name email phone notes].each do |field|
        update_attrs[field] = params[field] if params.key?(field)
      end
      update_attrs[:role_title] = params[:role_title] || params[:roleTitle] if params.key?(:role_title) || params.key?(:roleTitle)
      update_attrs[:is_primary] = truthy?(params[:is_primary] || params[:isPrimary]) if params.key?(:is_primary) || params.key?(:isPrimary)
      update_attrs[:receives_updates] = truthy?(params[:receives_updates]) if params.key?(:receives_updates)

      unless @contact.update(update_attrs)
        return render json: { error: @contact.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      render json: { success: true, contact: serialize_contact(@contact.reload) }
    end

    # DELETE /sales/partners/:partner_id/contacts/:id
    def destroy
      @contact.destroy
      render json: { success: true }
    end

    # POST /sales/partners/:partner_id/contacts/:id/invite
    # Send a partnership-confirmation invite to this contact (non-selling
    # partners like NCBA Loop — the contact acknowledges, no account needed).
    def invite
      invite = PartnerInviteIssuer.call(@contact, actor: @current_actor,
                                                 email: params[:email], phone: params[:phone])
      PartnerInviteJob.perform_later(invite.id)
      render json: { success: true, invite: serialize_invite(invite) }
    rescue PartnerInviteIssuer::Error, ActiveRecord::RecordInvalid => e
      render json: { error: e.respond_to?(:record) ? e.record.errors.full_messages.join(', ') : e.message },
             status: :unprocessable_entity
    end

    private

    def set_partner
      @partner = Partner.find_by(id: params[:partner_id])
      render json: { error: 'Partner not found' }, status: :not_found unless @partner
    end

    def set_contact
      @contact = @partner.contacts.find_by(id: params[:id])
      render json: { error: 'Contact not found' }, status: :not_found unless @contact
    end

    def truthy?(value)
      value == true || value.to_s == 'true'
    end

    def serialize_invite(invite)
      return nil unless invite

      {
        id: invite.id,
        status: invite.status,
        invite_kind: invite.invite_kind,
        expires_at: invite.expires_at,
        accepted_at: invite.accepted_at
      }
    end

    def serialize_contact(contact)
      {
        id: contact.id,
        partner_id: contact.partner_id,
        name: contact.name,
        role_title: contact.role_title,
        email: contact.email,
        phone: contact.phone,
        is_primary: contact.is_primary,
        receives_updates: contact.receives_updates,
        notes: contact.notes,
        created_at: contact.created_at
      }
    end
  end
end
