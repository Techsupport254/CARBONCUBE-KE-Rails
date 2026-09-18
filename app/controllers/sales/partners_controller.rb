# frozen_string_literal: true

module Sales
  # Partners — formal business relationships (brand manufacturers,
  # distributors, financiers like NCBA Loop, logistics, services). Tracks the
  # partnership lifecycle, a full touchpoint timeline, distributors, contacts,
  # broadcasts, and join invites.
  class PartnersController < ApplicationController
    include SalesOrAdminAuthenticatable
    include PartnerLogoUploadable

    before_action :authenticate_sales_or_admin
    before_action :set_partner, only: %i[show update destroy create_activity invite resend_invite link_seller]

    # GET /sales/partners
    # Params: search, partner_type, status, follow_up (scheduled|overdue|today|upcoming),
    #         page, per_page
    def index
      page = (params[:page].presence || 1).to_i
      per_page = (params[:per_page].presence || 25).to_i.clamp(1, 100)

      partners = Partner.includes(:sales_user, :activities).all
      partners = partners.search(params[:search]) if params[:search].present?
      partners = partners.where(partner_type: params[:partner_type]) if Partner.partner_types.key?(params[:partner_type].to_s)
      partners = partners.where(status: params[:status]) if Partner.statuses.key?(params[:status].to_s)

      case params[:follow_up]
      when 'scheduled' then partners = partners.with_follow_up
      when 'overdue'   then partners = partners.follow_up_overdue
      when 'today'     then partners = partners.follow_up_today
      when 'upcoming'  then partners = partners.follow_up_upcoming
      end

      partners = partners.order(:name)
      total_count = partners.count
      partners = partners.offset((page - 1) * per_page).limit(per_page)

      render json: {
        data: partners.map { |p| serialize_partner(p) },
        meta: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      }
    end

    # GET /sales/partners/:id
    # Partner detail + full activity timeline + distributors + contacts + updates.
    def show
      render json: serialize_partner(@partner).merge(
        seller: serialize_seller(@partner.seller),
        activities: @partner.activities.includes(:sales_user).map { |a| serialize_activity(a) },
        contacts: @partner.contacts.map { |c| serialize_contact(c) },
        distributors: @partner.distributors.includes(:seller).map { |d| serialize_distributor(d) },
        updates: @partner.updates.limit(50).map { |u| serialize_update(u) },
        pending_invite: serialize_invite(@partner.pending_invite)
      )
    end

    # POST /sales/partners
    # Create a partner with full details. Optionally link an existing seller
    # (sellerId), create a shell seller account (createSeller: true), seed
    # contacts[], and fire the join invite (sendInvite: true).
    def create
      existing = find_duplicate_partner
      if existing
        return render json: {
          success: true,
          existing: true,
          partner: serialize_partner(existing)
        }
      end

      logo = partner_logo_attrs
      if logo == :error
        return render json: { error: PartnerLogoUploadable::LOGO_ERROR }, status: :unprocessable_entity
      end

      partner = Partner.new(partner_attrs.merge(logo))
      partner.sales_user ||= current_sales_user
      # This surface is for onboarding — partners are registered after
      # they've agreed, so the default is active (signed_on stamped),
      # not negotiating.
      partner.status = 'active' if params[:status].blank?
      partner.signed_on ||= Date.current if partner.status == 'active'

      ActiveRecord::Base.transaction do
        handle_seller_assignment(partner)
        partner.save!

        Array(params[:contacts]).each do |c|
          partner.contacts.create!(
            name: c[:name], role_title: c[:role_title], email: c[:email],
            phone: c[:phone], is_primary: c[:is_primary], notes: c[:notes]
          )
        end
      end

      invite_error = nil
      if truthy?(params[:sendInvite])
        begin
          invite = PartnerInviteIssuer.call(partner, actor: @current_actor)
          PartnerInviteJob.perform_later(invite.id)
        rescue PartnerInviteIssuer::Error, ActiveRecord::RecordInvalid => e
          invite_error = e.respond_to?(:record) ? e.record.errors.full_messages.join(', ') : e.message
        end
      end

      render json: { success: true, partner: serialize_partner(partner.reload), invite_error: invite_error },
             status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
    rescue PartnerInviteIssuer::Error, ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # PATCH /sales/partners/:id
    # Update any partner field. Status changes go through transition_to! which
    # enforces per-status rules and logs to the timeline.
    def update
      update_attrs = {}

      %i[name contact_person phone email website location description logo_url
         agreement_notes notes].each do |field|
        update_attrs[field] = params[field] if params.key?(field)
      end
      logo = partner_logo_attrs
      if logo == :error
        return render json: { error: PartnerLogoUploadable::LOGO_ERROR }, status: :unprocessable_entity
      end
      update_attrs.merge!(logo)
      update_attrs[:partner_type] = params[:partner_type] if Partner.partner_types.key?(params[:partner_type].to_s)
      update_attrs[:commission_rate] = params[:commission_rate] if params.key?(:commission_rate)
      update_attrs[:signed_on] = params[:signed_on] if params.key?(:signed_on)
      update_attrs[:sales_user_id] = params[:salesUserId].presence if params.key?(:salesUserId)
      update_attrs[:last_contacted_at] = Time.current if params[:markContacted].to_s == 'true'

      unless params.key?(:status)
        update_attrs[:follow_up_date] = params[:followUpDate].presence if params.key?(:followUpDate)
        update_attrs[:follow_up_note] = params[:followUpNote] if params.key?(:followUpNote)
      end

      if params[:sellerId].present?
        seller = Seller.find_by(id: params[:sellerId])
        return render json: { error: 'Seller not found' }, status: :not_found unless seller

        @partner.link_seller!(seller, actor: @current_actor)
      end

      if update_attrs.any? && !@partner.update(update_attrs)
        return render json: { error: @partner.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      if params.key?(:status)
        unless Partner.statuses.key?(params[:status].to_s)
          return render json: { error: "Invalid status '#{params[:status]}'" }, status: :unprocessable_entity
        end

        begin
          @partner.transition_to!(
            params[:status],
            actor: @current_actor,
            note: params[:statusNote] || params[:followUpNote],
            signed_on: params[:signedOn],
            follow_up_date: params[:followUpDate],
            follow_up_note: params[:followUpNote]
          )
        rescue Partner::TransitionError => e
          return render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      render json: { success: true, partner: serialize_partner(@partner.reload) }
    end

    # DELETE /sales/partners/:id
    # Active partners can't be deleted — end the partnership first.
    def destroy
      if @partner.active?
        return render json: { error: 'Active partners cannot be deleted — end the partnership first' },
                      status: :forbidden
      end

      @partner.destroy
      render json: { success: true }
    end

    # GET /sales/partners/follow_ups
    def follow_ups
      scheduled = Partner.includes(:sales_user, activities: :sales_user)
                         .with_follow_up
                         .order(follow_up_date: :asc)

      render json: {
        data: scheduled.map { |p| serialize_partner(p).merge(follow_up_bucket: follow_up_bucket(p)) }
      }
    end

    # GET /sales/partners/stats
    def stats
      render json: {
        total: Partner.count,
        by_status: Partner.group(:status).count,
        by_type: Partner.group(:partner_type).count,
        follow_ups_overdue: Partner.follow_up_overdue.count,
        follow_ups_today: Partner.follow_up_today.count,
        follow_ups_upcoming: Partner.follow_up_upcoming.count,
        visits_total: PartnerActivity.where(activity_type: 'visit').count,
        calls_total: PartnerActivity.where(activity_type: 'call').count,
        distributors_total: PartnerDistributor.count,
        invites_pending: PartnerInvite.pending.count,
        on_platform: Partner.where.not(seller_id: nil).count,
        partner_types: Partner.partner_types.keys,
        statuses: Partner.statuses.keys
      }
    end

    # POST /sales/partners/:id/activities
    def create_activity
      type = params[:activityType].to_s
      unless PartnerActivity.activity_types.key?(type)
        return render json: { error: "Invalid activity type '#{type}'" }, status: :unprocessable_entity
      end

      activity = @partner.record_activity!(
        type: type,
        user: @current_actor,
        occurred_at: parse_time(params[:occurredAt]),
        notes: params[:notes],
        outcome: params[:outcome],
        follow_up_date: params[:followUpDate].presence,
        latitude: params[:latitude].presence,
        longitude: params[:longitude].presence
      )

      render json: { success: true, activity: serialize_activity(activity), partner: serialize_partner(@partner.reload) }
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /sales/partners/:id/invite
    # Send (or create + send) the join invite via email + WhatsApp.
    def invite
      invite = PartnerInviteIssuer.call(@partner, actor: @current_actor,
                                                 email: params[:email], phone: params[:phone])
      PartnerInviteJob.perform_later(invite.id)
      render json: { success: true, invite: serialize_invite(invite), partner: serialize_partner(@partner.reload) }
    rescue PartnerInviteIssuer::Error, ActiveRecord::RecordInvalid => e
      render json: { error: e.respond_to?(:record) ? e.record.errors.full_messages.join(', ') : e.message },
             status: :unprocessable_entity
    end

    # POST /sales/partners/:id/resend_invite
    # Revokes the pending invite and mints a fresh token + 7-day window.
    def resend_invite
      pending = @partner.pending_invite
      return render json: { error: 'No pending invite to resend' }, status: :unprocessable_entity unless pending

      invite = pending.resend!(invited_by: @current_actor)
      PartnerInviteJob.perform_later(invite.id)
      render json: { success: true, invite: serialize_invite(invite) }
    end

    # POST /sales/partners/:id/link_seller
    # Link a platform seller by id, or auto-match by the partner's phone/email.
    def link_seller
      seller = if params[:sellerId].present?
                 Seller.find_by(id: params[:sellerId])
               else
                 @partner.matching_seller
               end

      return render json: { error: 'No matching seller found' }, status: :not_found unless seller

      @partner.link_seller!(seller, actor: @current_actor)
      render json: { success: true, partner: serialize_partner(@partner.reload) }
    end

    private

    def set_partner
      @partner = Partner.find_by(id: params[:id])
      render json: { error: 'Partner not found' }, status: :not_found unless @partner
    end

    def partner_attrs
      {
        name: params[:name],
        partner_type: params[:partner_type].presence_in(Partner.partner_types.keys) || 'brand_manufacturer',
        status: params[:status].presence_in(Partner.statuses.keys),
        contact_person: params[:contact_person].presence || params[:contactPerson].presence,
        phone: params[:phone].presence,
        email: params[:email].presence,
        website: params[:website].presence,
        location: params[:location].presence,
        description: params[:description].presence,
        logo_url: params[:logo_url].presence || params[:logoUrl].presence,
        signed_on: params[:signed_on].presence || params[:signedOn].presence,
        agreement_notes: params[:agreement_notes].presence || params[:agreementNotes].presence,
        commission_rate: params[:commission_rate].presence || params[:commissionRate].presence,
        notes: params[:notes].presence,
        sales_brand_id: params[:sales_brand_id].presence || params[:salesBrandId].presence
      }.compact
    end

    # Decide the seller situation for a new partner:
    # - sellerId param → link that seller
    # - createSeller truthy → provision a shell account (activates via invite)
    # - otherwise → try to auto-match an existing seller
    def handle_seller_assignment(partner)
      if params[:sellerId].present?
        seller = Seller.find_by(id: params[:sellerId])
        raise ArgumentError, 'Seller not found' unless seller

        partner.seller_id = seller.id
      elsif truthy?(params[:createSeller])
        partner.seller = PartnerInviteIssuer.provision_shell_seller(partner)
      else
        partner.seller_id ||= partner.matching_seller&.id
      end
    end

    def follow_up_bucket(partner)
      return nil if partner.follow_up_date.blank?

      if partner.follow_up_date < Date.current
        'overdue'
      elsif partner.follow_up_date == Date.current
        'today'
      else
        'upcoming'
      end
    end

    def find_duplicate_partner
      if params[:phone].present?
        digits = params[:phone].to_s.gsub(/\D/, '')
        if digits.length >= 9
          suffix = digits[-9..]
          match = Partner.where('phone LIKE ?', "%#{suffix}").first
          return match if match
        end
      end

      return nil if params[:name].blank?

      Partner.where('LOWER(name) = ?', params[:name].to_s.strip.downcase).first
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def truthy?(value)
      value == true || value.to_s == 'true'
    end

    def serialize_partner(partner)
      PartnerPresenter.partner(partner)
    end

    def serialize_activity(activity)
      PartnerPresenter.activity(activity)
    end

    def serialize_contact(contact)
      PartnerPresenter.contact(contact)
    end

    def serialize_distributor(distributor)
      PartnerPresenter.distributor(distributor)
    end

    def serialize_update(update)
      PartnerPresenter.update(update)
    end

    def serialize_invite(invite)
      PartnerPresenter.invite(invite)
    end

    def serialize_seller(seller)
      PartnerPresenter.seller(seller)
    end
  end
end
