# frozen_string_literal: true

class Seller::GoogleBusinessProfilesController < ApplicationController
  before_action :authenticate_seller, except: :callback
  before_action :set_connection, only: %i[status locations select_location sync disconnect]

  # POST /seller/google-business-profile/authorize
  def authorize
    unless GoogleBusinessProfileService.configured?
      return render json: { error: 'Google Business Profile is not configured yet.' }, status: :service_unavailable
    end

    state = SecureRandom.urlsafe_base64(32)
    Rails.cache.write(state_cache_key(state), current_seller.id, expires_in: 10.minutes)
    render json: { authorization_url: GoogleBusinessProfileService.authorization_url(state) }
  end

  # GET /seller/google-business-profile/callback
  def callback
    seller_id = Rails.cache.delete(state_cache_key(params[:state].to_s))
    return redirect_to_frontend('error=invalid_state') if seller_id.blank?
    return redirect_to_frontend('error=access_denied') if params[:error].present?

    connection = GoogleBusinessProfileConnection.find_or_initialize_by(seller_id: seller_id)
    tokens = GoogleBusinessProfileService.exchange_code(params[:code])
    connection.assign_attributes(
      access_token: tokens.fetch('access_token'),
      refresh_token: tokens['refresh_token'].presence || connection.refresh_token,
      access_token_expires_at: tokens.fetch('expires_in').to_i.seconds.from_now,
      status: 'connected',
      connected_at: Time.current,
      last_sync_error: nil
    )
    connection.save!

    # If the user manages exactly one Business Profile location, auto-select it and sync immediately
    begin
      service = GoogleBusinessProfileService.new(connection)
      candidate_locations = service.locations
      if candidate_locations.size == 1
        loc = candidate_locations.first
        connection.update!(
          google_account_id: loc[:account_id],
          google_location_id: loc[:location_id],
          location_name: loc[:title],
          location_address: loc[:address],
          status: 'connected',
          last_sync_error: nil
        )

        seller_updates = {}
        seller_updates[:google_place_id] = loc[:place_id] if loc[:place_id].present?
        seller_updates[:google_business_profile_url] = loc[:maps_uri] if loc[:maps_uri].present?
        connection.seller.update!(seller_updates) if seller_updates.any?

        service.sync_reviews!
        return redirect_to_frontend('google_business_profile=synced')
      end
    rescue StandardError => e
      Rails.logger.warn("Auto-location selection on Google Business Profile callback failed: #{e.message}")
    end

    redirect_to_frontend('google_business_profile=connected')
  rescue GoogleBusinessProfileService::ApiError, KeyError => e
    Rails.logger.warn("Google Business Profile connection failed: #{e.message}")
    redirect_to_frontend('error=google_business_profile_connection_failed')
  end

  # GET /seller/google-business-profile/status
  def status
    render json: connection_payload(@connection)
  end

  # GET /seller/google-business-profile/locations
  def locations
    unless @connection&.connected?
      return render json: { error: 'Connect Google Business Profile first.' }, status: :unprocessable_entity
    end

    render json: { locations: GoogleBusinessProfileService.new(@connection).locations }
  rescue GoogleBusinessProfileService::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /seller/google-business-profile/select-location
  def select_location
    unless @connection&.connected?
      return render json: { error: 'Connect Google Business Profile first.' }, status: :unprocessable_entity
    end

    location = GoogleBusinessProfileService.new(@connection).locations.find do |candidate|
      candidate[:account_id].to_s == params[:account_id].to_s && candidate[:location_id].to_s == params[:location_id].to_s
    end
    return render json: { error: 'Selected location is not available to this Google account.' }, status: :unprocessable_entity if location.blank?

    @connection.update!(
      google_account_id: location[:account_id],
      google_location_id: location[:location_id],
      location_name: location[:title],
      location_address: location[:address],
      status: 'connected',
      last_sync_error: nil
    )

    seller_updates = {}
    seller_updates[:google_place_id] = location[:place_id] if location[:place_id].present?
    seller_updates[:google_business_profile_url] = location[:maps_uri] if location[:maps_uri].present?
    current_seller.update!(seller_updates) if seller_updates.any?

    GoogleBusinessProfileService.new(@connection).sync_reviews!
    render json: connection_payload(@connection.reload)
  rescue GoogleBusinessProfileService::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /seller/google-business-profile/sync
  def sync
    GoogleBusinessProfileService.new(@connection).sync_reviews!
    render json: connection_payload(@connection.reload)
  rescue GoogleBusinessProfileService::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /seller/google-business-profile
  def disconnect
    return head :no_content unless @connection

    @connection.update!(
      access_token: nil,
      refresh_token: nil,
      access_token_expires_at: nil,
      google_account_id: nil,
      google_location_id: nil,
      location_name: nil,
      location_address: nil,
      status: 'disconnected',
      last_sync_error: nil,
      review_count: 0,
      average_rating: nil,
      last_synced_at: nil
    )

    current_seller.update!(
      google_place_reviews: [],
      google_reviews_fetched_at: nil,
      google_place_id: nil,
      google_place_id_fetched_at: nil,
      google_business_profile_url: nil
    )

    render json: connection_payload(@connection)
  end

  private

  def authenticate_seller
    @current_seller = SellerAuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: :unauthorized unless @current_seller.is_a?(Seller)
  end

  def current_seller
    @current_seller
  end

  def set_connection
    @connection = GoogleBusinessProfileConnection.find_by(seller_id: current_seller.id)
  end

  def connection_payload(connection)
    return { connected: false } if connection.blank? || !connection.connected?

    {
      connected: true,
      location_selected: connection.google_location_id.present?,
      location: {
        name: connection.location_name,
        address: connection.location_address,
        maps_uri: connection.seller.google_business_profile_url
      },
      review_count: connection.review_count,
      average_rating: connection.average_rating,
      last_synced_at: connection.last_synced_at,
      status: connection.status,
      error: connection.last_sync_error
    }
  end

  def state_cache_key(state)
    "google_business_profile_oauth:#{Digest::SHA256.hexdigest(state)}"
  end

  def redirect_to_frontend(query)
    frontend_url = ENV['FRONTEND_URL'].presence || ENV['REACT_APP_FRONTEND_URL'].presence || (Rails.env.development? ? 'http://localhost:3000' : 'https://carboncube-ke.com')
    redirect_to "#{frontend_url}/profile?tab=business&#{query}", allow_other_host: true, status: :found
  end
end
