# frozen_string_literal: true

module Sales
  # Distributor network under a partner — the businesses that resell the
  # partner's products and subscribe to pricing/announcement updates.
  class PartnerDistributorsController < ApplicationController
    include SalesOrAdminAuthenticatable

    before_action :authenticate_sales_or_admin
    before_action :set_partner
    before_action :set_distributor, only: %i[update destroy invite resend_invite]

    # GET /sales/partners/:partner_id/distributors
    def index
      render json: {
        data: @partner.distributors.includes(:seller).map { |d| serialize_distributor(d) }
      }
    end

    # POST /sales/partners/:partner_id/distributors
    # Add a distributor. Dedups on normalized phone, then exact name within
    # this partner's network.
    def create
      existing = find_duplicate_distributor
      if existing
        return render json: {
          success: true,
          existing: true,
          distributor: serialize_distributor(existing)
        }
      end

      distributor = @partner.distributors.new(
        name: params[:name],
        contact_person: params[:contact_person].presence || params[:contactPerson].presence,
        phone: params[:phone].presence,
        email: params[:email].presence,
        location: params[:location].presence,
        notes: params[:notes].presence,
        notify_pricing: params.key?(:notify_pricing) ? truthy?(params[:notify_pricing]) : true,
        notify_updates: params.key?(:notify_updates) ? truthy?(params[:notify_updates]) : true,
        sales_user: current_sales_user,
        actor_name: current_actor_name
      )
      distributor.seller_id = params[:sellerId].presence || distributor.matching_seller&.id
      distributor.status = distributor.seller_id.present? ? 'active' : 'invited'

      unless distributor.save
        return render json: { error: distributor.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      render json: { success: true, distributor: serialize_distributor(distributor) }, status: :created
    end

    # PATCH /sales/partners/:partner_id/distributors/:id
    def update
      update_attrs = {}
      %i[name contact_person phone email location notes].each do |field|
        update_attrs[field] = params[field] if params.key?(field)
      end
      update_attrs[:notify_pricing] = truthy?(params[:notify_pricing]) if params.key?(:notify_pricing)
      update_attrs[:notify_updates] = truthy?(params[:notify_updates]) if params.key?(:notify_updates)

      if params.key?(:status)
        unless PartnerDistributor.statuses.key?(params[:status].to_s)
          return render json: { error: "Invalid status '#{params[:status]}'" }, status: :unprocessable_entity
        end
        update_attrs[:status] = params[:status]
      end

      if params.key?(:sellerId)
        seller = Seller.find_by(id: params[:sellerId])
        return render json: { error: 'Seller not found' }, status: :not_found unless seller

        update_attrs[:seller_id] = seller.id
        update_attrs[:status] = 'active' if @distributor.invited?
      end

      unless @distributor.update(update_attrs)
        return render json: { error: @distributor.errors.full_messages.join(', ') },
                      status: :unprocessable_entity
      end

      render json: { success: true, distributor: serialize_distributor(@distributor.reload) }
    end

    # DELETE /sales/partners/:partner_id/distributors/:id
    def destroy
      @distributor.destroy
      render json: { success: true }
    end

    # POST /sales/partners/:partner_id/distributors/:id/invite
    def invite
      invite = PartnerInviteIssuer.call(@distributor, actor: @current_actor,
                                                     email: params[:email], phone: params[:phone])
      PartnerInviteJob.perform_later(invite.id)
      render json: {
        success: true,
        invite: serialize_invite(invite),
        distributor: serialize_distributor(@distributor.reload)
      }
    rescue PartnerInviteIssuer::Error, ActiveRecord::RecordInvalid => e
      render json: { error: e.respond_to?(:record) ? e.record.errors.full_messages.join(', ') : e.message },
             status: :unprocessable_entity
    end

    # POST /sales/partners/:partner_id/distributors/:id/resend_invite
    def resend_invite
      pending = @distributor.pending_invite
      return render json: { error: 'No pending invite to resend' }, status: :unprocessable_entity unless pending

      invite = pending.resend!(invited_by: @current_actor)
      PartnerInviteJob.perform_later(invite.id)
      render json: { success: true, invite: serialize_invite(invite) }
    end

    private

    def set_partner
      @partner = Partner.find_by(id: params[:partner_id])
      render json: { error: 'Partner not found' }, status: :not_found unless @partner
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
        accepted_at: invite.accepted_at,
        reminder_count: invite.reminder_count
      }
    end

    def serialize_distributor(distributor)
      {
        id: distributor.id,
        partner_id: distributor.partner_id,
        name: distributor.name,
        contact_person: distributor.contact_person,
        phone: distributor.phone,
        email: distributor.email,
        location: distributor.location,
        status: distributor.status,
        notify_pricing: distributor.notify_pricing,
        notify_updates: distributor.notify_updates,
        seller_id: distributor.seller_id,
        seller_name: distributor.seller&.enterprise_name || distributor.seller&.fullname,
        seller_slug: distributor.seller&.slug,
        agent_name: distributor.sales_user&.fullname || distributor.actor_name,
        notes: distributor.notes,
        pending_invite: serialize_invite(distributor.pending_invite),
        created_at: distributor.created_at
      }
    end
  end
end
