class Sales::SellerRankingsController < ApplicationController
  before_action :authenticate_sales_user

  # GET /sales/seller_rankings
  # Get ranked sellers by composite score (aggregated metrics)
  def index
    begin
      filters = {
        tier_id: params[:tier_id],
        category_id: params[:category_id]
      }.compact

      limit = params[:limit].to_i
      limit = 100 if limit < 1 || limit > 500

      service = SellerRankingService.new(filters: filters)
      ranked_sellers = service.ranked_sellers(limit: limit)

      # Assign ranks
      ranked_sellers.each_with_index do |seller_data, index|
        seller_data[:rank] = index + 1
      end

      render json: {
        rankings: ranked_sellers,
        total: ranked_sellers.count,
        filters: filters
      }
    rescue => e
      Rails.logger.error "Seller rankings error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
  end

  # GET /sales/seller_rankings/by_metric
  # Get rankings by specific metric (ad_clicks, reveal_clicks, wishlists_count, reviews_count, avg_rating)
  def by_metric
    begin
      metric_type = params[:metric_type] || 'composite_score'
      valid_metrics = %w[ad_clicks reveal_clicks wishlists_count reviews_count avg_rating composite_score]
      
      unless valid_metrics.include?(metric_type)
        render json: { error: "Invalid metric_type. Must be one of: #{valid_metrics.join(', ')}" }, status: :bad_request
        return
      end

      filters = {
        tier_id: params[:tier_id],
        category_id: params[:category_id]
      }.compact

      limit = params[:limit].to_i
      limit = 100 if limit < 1 || limit > 500

      service = SellerRankingService.new(filters: filters)
      
      if metric_type == 'composite_score'
        ranked_sellers = service.ranked_sellers(limit: limit)
      else
        ranked_sellers = service.rankings_by_metric(metric_type, limit: limit)
      end

      render json: {
        rankings: ranked_sellers,
        metric_type: metric_type,
        total: ranked_sellers.count,
        filters: filters
      }
    rescue => e
      Rails.logger.error "Seller rankings by metric error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error', details: e.message }, status: 500
    end
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end

