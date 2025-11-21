# app/controllers/geocoding_controller.rb
require 'httparty'

class GeocodingController < ApplicationController
  # Reverse geocoding: Convert lat/lng to address using Nominatim
  def reverse
    latitude = params[:lat]&.to_f
    longitude = params[:lon]&.to_f
    zoom = params[:zoom]&.to_i || 18 # Default to zoom 18 for detailed results
    
    unless latitude && longitude
      render json: { error: 'Latitude and longitude are required' }, status: :bad_request
      return
    end
    
    begin
      # Use Nominatim API for reverse geocoding
      # Note: Nominatim requires a User-Agent header and has usage policies
      nominatim_url = 'https://nominatim.openstreetmap.org/reverse'
      
      response = HTTParty.get(nominatim_url, {
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
        data = JSON.parse(response.body)
        render json: data, status: :ok
      else
        Rails.logger.error "Nominatim API error: #{response.code} - #{response.body}"
        render json: { 
          error: 'Failed to get location data',
          display_name: "#{latitude}, #{longitude}"
        }, status: :bad_gateway
      end
    rescue => e
      Rails.logger.error "Geocoding error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      render json: { 
        error: 'Geocoding service unavailable',
        display_name: "#{latitude}, #{longitude}"
      }, status: :internal_server_error
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
    
    begin
      # Use Nominatim API for forward geocoding/search
      # Note: Nominatim requires a User-Agent header and has usage policies
      nominatim_url = 'https://nominatim.openstreetmap.org/search'
      
      response = HTTParty.get(nominatim_url, {
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
        data = JSON.parse(response.body)
        # Ensure we return an array
        render json: Array(data), status: :ok
      else
        Rails.logger.error "Nominatim search API error: #{response.code} - #{response.body}"
        render json: [], status: :bad_gateway
      end
    rescue => e
      Rails.logger.error "Geocoding search error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      render json: [], status: :internal_server_error
    end
  end
end

