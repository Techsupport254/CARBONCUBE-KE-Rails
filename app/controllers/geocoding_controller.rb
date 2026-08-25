# app/controllers/geocoding_controller.rb
require 'httparty'

class GeocodingController < ApplicationController
  # Nominatim requires ~1 second between requests from the same IP.
  # This mutex enforces that within a single Rails process.
  NOMINATIM_MIN_INTERVAL = 1.0
  MUTEX = Mutex.new

  class << self
    attr_accessor :last_nominatim_request_at
  end

  # Reverse geocoding: Convert lat/lng to address using Nominatim
  def reverse
    latitude = params[:lat]&.to_f
    longitude = params[:lon]&.to_f
    zoom = params[:zoom]&.to_i || 18

    unless latitude && longitude
      render json: { error: 'Latitude and longitude are required' }, status: :bad_request
      return
    end

    cache_key = "nominatim:reverse:#{latitude.round(6)}:#{longitude.round(6)}:#{zoom}"
    data = fetch_or_request(cache_key) { nominatim_reverse(latitude, longitude, zoom) }

    if data
      render json: data, status: :ok
    else
      render json: {
        error: 'Failed to get location data',
        display_name: "#{latitude}, #{longitude}"
      }, status: :bad_gateway
    end
  end

  # Forward geocoding: Convert address/query to coordinates using Nominatim
  def search
    query = params[:q] || params[:query]
    limit = params[:limit]&.to_i || 5

    unless query.present?
      render json: { error: 'Query parameter is required' }, status: :bad_request
      return
    end

    cache_key = "nominatim:search:#{Digest::MD5.hexdigest("#{query}:#{limit}")}"
    data = fetch_or_request(cache_key) { nominatim_search(query, limit) }

    if data
      render json: Array(data), status: :ok
    else
      render json: [], status: :bad_gateway
    end
  end

  private

  def fetch_or_request(cache_key)
    data = Rails.cache.read(cache_key)
    if data.nil?
      data = yield
      Rails.cache.write(cache_key, data, expires_in: 1.hour) unless data.nil?
    end
    data
  end

  def nominatim_reverse(latitude, longitude, zoom)
    with_nominatim_rate_limit do
      response = HTTParty.get('https://nominatim.openstreetmap.org/reverse', {
        query: {
          format: 'json',
          lat: latitude,
          lon: longitude,
          addressdetails: 1,
          zoom: zoom
        },
        headers: {
          'User-Agent' => 'CarbonCube-Kenya/1.0 (contact: info@carboncube-ke.com)',
          'Accept' => 'application/json'
        },
        timeout: 10
      })

      if response.success?
        JSON.parse(response.body)
      else
        Rails.logger.error "Nominatim API error: #{response.code} - #{response.body}"
        nil
      end
    end
  rescue => e
    Rails.logger.error "Geocoding error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    nil
  end

  def nominatim_search(query, limit)
    with_nominatim_rate_limit do
      response = HTTParty.get('https://nominatim.openstreetmap.org/search', {
        query: {
          format: 'json',
          q: query,
          addressdetails: 1,
          limit: limit
        },
        headers: {
          'User-Agent' => 'CarbonCube-Kenya/1.0 (contact: info@carboncube-ke.com)',
          'Accept' => 'application/json'
        },
        timeout: 10
      })

      if response.success?
        JSON.parse(response.body)
      else
        Rails.logger.error "Nominatim search API error: #{response.code} - #{response.body}"
        nil
      end
    end
  rescue => e
    Rails.logger.error "Geocoding search error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    nil
  end

  def with_nominatim_rate_limit
    MUTEX.synchronize do
      last = self.class.last_nominatim_request_at
      if last
        wait = NOMINATIM_MIN_INTERVAL - (Time.current.to_f - last)
        sleep(wait) if wait > 0
      end
      result = yield
      self.class.last_nominatim_request_at = Time.current.to_f
      result
    end
  end
end
