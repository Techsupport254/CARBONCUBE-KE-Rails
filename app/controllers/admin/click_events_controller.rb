class Admin::ClickEventsController < ApplicationController
  before_action :set_click_event, only: [:show, :destroy]

  # GET /admin/click_events
  def index
    @click_events = ClickEvent.all

    # Optional: Filtering by event_type, ad_id, or buyer_id
    @click_events = @click_events.where(event_type: params[:event_type]) if params[:event_type].present?
    @click_events = @click_events.where(ad_id: params[:ad_id]) if params[:ad_id].present?
    @click_events = @click_events.where(buyer_id: params[:buyer_id]) if params[:buyer_id].present?

    # Use ActiveModelSerializers for rendering
    render json: @click_events, each_serializer: ClickEventSerializer, status: :ok
  end

  # GET /admin/click_events/:id
  def show
    render json: @click_event, serializer: ClickEventSerializer, status: :ok
  end

  # DELETE /admin/click_events/:id
  def destroy
    @click_event.destroy
    render json: { message: 'Click event deleted successfully' }, status: :ok
  end

  private

  def set_click_event
    @click_event = ClickEvent.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Click event not found' }, status: :not_found
  end
end
