class Api::V1::SellerLocationsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Build cache key based on max updated_at across relevant tables
    seller_ts = Seller.where(deleted: false).maximum(:updated_at).to_i
    branch_ts = Branch.maximum(:updated_at).to_i
    tier_ts = SellerTier.maximum(:updated_at).to_i
    seller_count = Seller.where(deleted: false).count

    cache_key = "api/v1/seller_locations/#{seller_ts}-#{branch_ts}-#{tier_ts}-#{seller_count}"

    # Return 304 Not Modified if client cache is fresh
    if stale?(etag: cache_key, public: false)
      response_data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
        # Count totals efficiently
        total_sellers = seller_count
        with_coordinates = Seller
          .where(deleted: false)
          .where(
            'EXISTS (SELECT 1 FROM branches WHERE branches.seller_id = sellers.id AND branches.latitude IS NOT NULL)'
          ).count
        without_coordinates = total_sellers - with_coordinates

        # Fetch sellers with eager loaded associations (no N+1 queries)
        sellers = Seller
          .includes(:county, :sub_county, seller_tier: :tier)
          .where(deleted: false)
          .order(ads_count: :desc, enterprise_name: :asc)

        # Fetch first geocoded branch coords per seller in one single indexed query
        seller_ids = sellers.map(&:id)
        branch_coords = Branch
          .where(seller_id: seller_ids)
          .where.not(latitude: nil)
          .select('DISTINCT ON (seller_id) seller_id, latitude, longitude, location_precision, name, location')
          .order('seller_id, id')
          .index_by(&:seller_id)

        # Fall back to any branch if no geocoded one
        first_branches = Branch
          .where(seller_id: seller_ids)
          .select('DISTINCT ON (seller_id) seller_id, latitude, longitude, location_precision, name, location')
          .order('seller_id, id')
          .index_by(&:seller_id)

        # Format the payload
        sellers_data = sellers.map do |seller|
          branch = branch_coords[seller.id] || first_branches[seller.id]
          full_location = [branch&.location, seller.location].compact.map(&:strip).reject(&:blank?).uniq.join(', ')
          full_location = seller.location if full_location.blank?

          {
            id: seller.id,
            fullname: seller.fullname,
            enterprise_name: seller.enterprise_name,
            location: full_location,
            branch_name: branch&.name,
            city: seller.city,
            county_name: seller.county&.name || 'Unknown',
            sub_county_name: seller.sub_county&.name || 'Unknown',
            latitude: branch&.latitude,
            longitude: branch&.longitude,
            location_precision: branch&.location_precision || 'approximate',
            phone_number: seller.phone_number,
            email: seller.email,
            profile_picture: seller.profile_picture,
            document_verified: seller.document_verified || false,
            ads_count: seller.ads_count,
            tier: seller.seller_tier&.tier&.name || 'Tier 1'
          }
        end

        {
          sellers: sellers_data,
          geocoding_status: {
            total: total_sellers,
            with_coordinates: with_coordinates,
            without_coordinates: without_coordinates
          }
        }
      end

      render json: response_data
    end
  end

  def geocode_batch
    force = params[:force].to_s == 'true'
    # Start a background job to geocode sellers without coordinates or needing precision correction
    GeocodeSellersJob.perform_later(nil, force: force)
    Rails.cache.delete_matched("api/v1/seller_locations/*") rescue nil
    
    render json: { 
      message: 'Geocoding batch job started',
      status: 'processing'
    }, status: :accepted
  end

  private

  def authenticate_sales_user
    @current_sales_user = SalesAuthorizeApiRequest.new(request.headers).result
    unless @current_sales_user
      render json: { error: 'Not Authorized' }, status: :unauthorized
    end
  end
end
