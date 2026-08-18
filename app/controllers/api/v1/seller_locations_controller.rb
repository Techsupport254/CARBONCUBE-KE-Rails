class Api::V1::SellerLocationsController < ApplicationController
  before_action :authenticate_sales_user

  def index
    # Count totals using subquery to avoid branch join duplication
    total_sellers = Seller.where(deleted: false).count
    with_coordinates = Seller
      .where(deleted: false)
      .where(
        'EXISTS (SELECT 1 FROM branches WHERE branches.seller_id = sellers.id AND branches.latitude IS NOT NULL)'
      ).count
    without_coordinates = total_sellers - with_coordinates

    # Fetch sellers with county/sub-county via includes (no branch join = no duplicates)
    sellers = Seller
      .includes(:county, :sub_county)
      .where(deleted: false)
      .distinct
      .order('sellers.enterprise_name ASC')

    # Fetch first geocoded branch coords per seller in one query
    branch_coords = Branch
      .where(seller_id: sellers.map(&:id))
      .where.not(latitude: nil)
      .select('DISTINCT ON (seller_id) seller_id, latitude, longitude, location_precision, name, location')
      .order('seller_id, id')
      .index_by(&:seller_id)

    # Fall back to any branch (even without coords) if no geocoded one
    first_branches = Branch
      .where(seller_id: sellers.map(&:id))
      .select('DISTINCT ON (seller_id) seller_id, latitude, longitude, location_precision, name, location')
      .order('seller_id, id')
      .index_by(&:seller_id)

    # Format the response
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
        ads_count: seller.ads_count
      }
    end

    render json: {
      sellers: sellers_data,
      geocoding_status: {
        total: total_sellers,
        with_coordinates: with_coordinates,
        without_coordinates: without_coordinates
      }
    }
  end

  def geocode_batch
    force = params[:force].to_s == 'true'
    # Start a background job to geocode sellers without coordinates or needing precision correction
    GeocodeSellersJob.perform_later(nil, force: force)
    
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
