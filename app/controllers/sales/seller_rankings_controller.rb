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

      cache_key = "sales_seller_rankings_index_v1_#{filters.to_param}_#{limit}"
      ranked_sellers = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        service = SellerRankingService.new(filters: filters)
        sellers = service.ranked_sellers(limit: limit)
        sellers.each_with_index do |seller_data, index|
          seller_data[:rank] = index + 1
        end
        sellers
      end

      if commission_sales?
        ranked_sellers = ranked_sellers.map do |s|
          s = s.dup
          s[:email] = mask_email(s[:email])
          s[:phone_number] = mask_phone(s[:phone_number])
          s
        end
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
  # Get rankings by specific metric (ad_clicks, reveal_clicks, copy_clicks, call_clicks, whatsapp_clicks, location_clicks, total_contact_interactions, wishlists_count, reviews_count, avg_rating)
  def by_metric
    begin
      metric_type = params[:metric_type] || 'composite_score'
      valid_metrics = %w[ad_clicks reveal_clicks copy_clicks call_clicks whatsapp_clicks location_clicks total_contact_interactions wishlists_count reviews_count avg_rating composite_score]
      
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

      cache_key = "sales_seller_rankings_metric_v1_#{metric_type}_#{filters.to_param}_#{limit}"
      ranked_sellers = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        service = SellerRankingService.new(filters: filters)
        if metric_type == 'composite_score'
          service.ranked_sellers(limit: limit)
        else
          service.rankings_by_metric(metric_type, limit: limit)
        end
      end

      if commission_sales?
        ranked_sellers = ranked_sellers.map do |s|
          s = s.dup
          s[:email] = mask_email(s[:email])
          s[:phone_number] = mask_phone(s[:phone_number])
          s
        end
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

  def commission_sales?
    @current_sales_user&.compensation_type == 'commission' && !@current_sales_user&.team_sales_dashboard_access?
  end

  def mask_email(email)
    return nil if email.blank?
    parts = email.to_s.strip.split('@')
    return email if parts.length != 2
    name, domain = parts
    masked_name = name.length > 2 ? "#{name[0]}***#{name[-1]}" : "#{name[0]}***"
    "#{masked_name}@#{domain}"
  end

  def mask_phone(phone)
    return nil if phone.blank?
    clean = phone.to_s.strip
    return clean if clean.length < 5
    "#{clean[0..3]}****#{clean[-2..]}"
  end
end

