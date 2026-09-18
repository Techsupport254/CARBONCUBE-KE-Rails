# frozen_string_literal: true

module Sales
  # Broadcasts from a partner to its distributor network + contacts — pricing,
  # announcements, promotions, restocks. Fan-out happens async via
  # PartnerUpdateFanoutJob (enqueued by the model's after_create_commit).
  class PartnerUpdatesController < ApplicationController
    include SalesOrAdminAuthenticatable

    before_action :authenticate_sales_or_admin
    before_action :set_partner

    # GET /sales/partners/:partner_id/updates
    def index
      updates = @partner.updates.includes(:sales_user)
      updates = updates.where(kind: params[:kind]) if PartnerUpdate.kinds.key?(params[:kind].to_s)

      render json: { data: updates.limit(100).map { |u| serialize_update(u) } }
    end

    # POST /sales/partners/:partner_id/updates
    def create
      return render json: { error: 'Title is required' }, status: :unprocessable_entity if params[:title].blank?

      update = @partner.updates.new(
        kind: params[:kind].presence_in(PartnerUpdate.kinds.keys) || 'announcement',
        title: params[:title],
        body: params[:body].presence,
        ad_id: params[:adId].presence || params[:ad_id].presence,
        metadata: params[:metadata].is_a?(ActionController::Parameters) ? params[:metadata].to_unsafe_h : {},
        sales_user: current_sales_user,
        actor_name: current_actor_name
      )

      unless update.save
        return render json: { error: update.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end

      render json: { success: true, update: serialize_update(update) }, status: :created
    end

    private

    def set_partner
      @partner = Partner.find_by(id: params[:partner_id])
      render json: { error: 'Partner not found' }, status: :not_found unless @partner
    end

    def serialize_update(update)
      {
        id: update.id,
        kind: update.kind,
        title: update.title,
        body: update.body,
        ad_id: update.ad_id,
        metadata: update.metadata,
        agent_name: update.sales_user&.fullname || update.actor_name,
        created_at: update.created_at
      }
    end
  end
end
