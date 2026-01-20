class Admin::AdSearchesController < ApplicationController
  before_action :set_ad_search, only: [:show, :destroy]

  # GET /admin/ad_searches
  def index
    page = params[:page].to_i.positive? ? params[:page].to_i : 1
    per_page = params[:per_page].to_i.positive? ? params[:per_page].to_i : 50

    # Build filters from params
    filters = {}
    filters[:search_term] = params[:search_term] if params[:search_term].present?
    filters[:buyer_id] = params[:buyer_id] if params[:buyer_id].present?
    filters[:start_date] = params[:start_date] if params[:start_date].present?
    filters[:end_date] = params[:end_date] if params[:end_date].present?

    # Get search history from Redis
    result = SearchRedisService.search_history(
      page: page,
      per_page: per_page,
      filters: filters
    )

    # Format response to match existing serializer expectations
    formatted_searches = result[:searches].map do |search|
      # Convert to format expected by AdSearchSerializer
      search.merge(
        id: search[:id],
        search_term: search[:search_term],
        buyer_id: search[:buyer_id],
        created_at: search[:timestamp]
      )
    end

    render json: {
      searches: formatted_searches,
      meta: {
        current_page: result[:current_page],
        per_page: result[:per_page],
        total_count: result[:total_count],
        total_pages: result[:total_pages]
      }
    }, status: :ok
  end

  # GET /admin/ad_searches/:id
  def show
    # For Redis, we can't easily find by ID since keys are generated
    # Instead, return analytics or suggest using the index endpoint with filters
    render json: {
      error: 'Individual search lookup not supported with Redis storage. Use the index endpoint with filters instead.',
      suggestion: 'Use GET /admin/ad_searches with filters to find specific searches'
    }, status: :not_found
  end

  # DELETE /admin/ad_searches/:id
  def destroy
    # Redis data is ephemeral and expires automatically
    # For admin purposes, we can acknowledge the request but not actually delete
    render json: {
      message: 'Search data is stored in Redis with automatic expiration. Individual records cannot be deleted but will expire automatically.',
      note: 'Data expires after 30 days for individual searches, 90 days for analytics.'
    }, status: :ok
  end

  # GET /admin/ad_searches/analytics
  def analytics
    analytics_data = SearchRedisService.analytics

    # Get popular searches for different timeframes
    popular_searches = {
      all_time: SearchRedisService.popular_searches(10, :all),
      daily: SearchRedisService.popular_searches(10, :daily),
      weekly: SearchRedisService.popular_searches(10, :weekly),
      monthly: SearchRedisService.popular_searches(10, :monthly)
    }

    popular_data = {
      all_time: SearchRedisService.popular_searches(10, :all),
      daily: SearchRedisService.popular_searches(10, :daily),
      weekly: SearchRedisService.popular_searches(10, :weekly),
      monthly: SearchRedisService.popular_searches(10, :monthly)
    }

    render json: {
      analytics: analytics_data,
      popular_searches: popular_data,
      data_retention: {
        individual_searches: '30 days',
        analytics_data: '90 days'
      }
    }, status: :ok
  end

  private

  def set_ad_search
    @ad_search = AdSearch.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Ad search not found' }, status: :not_found
  end
end
