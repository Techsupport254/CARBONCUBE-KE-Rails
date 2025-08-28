class Admin::AdSearchesController < ApplicationController
  before_action :set_ad_search, only: [:show, :destroy]

  # GET /admin/ad_searches
  def index
    @ad_searches = AdSearch.all

    # Optional: Filtering by search_term or buyer_id
    @ad_searches = @ad_searches.where("search_term ILIKE ?", "%#{params[:search_term]}%") if params[:search_term].present?
    @ad_searches = @ad_searches.where(buyer_id: params[:buyer_id]) if params[:buyer_id].present?

    # Use ActiveModelSerializers for rendering
    render json: @ad_searches, each_serializer: AdSearchSerializer, status: :ok
  end

  # GET /admin/ad_searches/:id
  def show
    render json: @ad_search, serializer: AdSearchSerializer, status: :ok
  end

  # DELETE /admin/ad_searches/:id
  def destroy
    @ad_search.destroy
    render json: { message: 'Ad search deleted successfully' }, status: :ok
  end

  private

  def set_ad_search
    @ad_search = AdSearch.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad search not found' }, status: :not_found
  end
end
