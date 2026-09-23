class Api::V1::SellerLocationsController < ApplicationController
  include SalesOrAdminAuthenticatable

  before_action :authenticate_sales_or_admin

  def index
    # Build cache key based on max updated_at across relevant tables
    seller_ts = Seller.where(deleted: false).maximum(:updated_at).to_i
    branch_ts = Branch.maximum(:updated_at).to_i
    tier_ts = SellerTier.maximum(:updated_at).to_i
    review_ts = Review.maximum(:updated_at).to_i
    google_reviews_ts = Seller.maximum(:google_reviews_fetched_at).to_i
    seller_count = Seller.where(deleted: false).count
    # categories_sellers is a join table without timestamps — bust on row count
    categories_sellers_count = CategoriesSeller.count

    cache_key = "api/v1/seller_locations/#{seller_ts}-#{branch_ts}-#{tier_ts}-#{review_ts}-#{google_reviews_ts}-#{seller_count}-#{categories_sellers_count}-v3"

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
          .includes(:county, :sub_county, :google_business_profile_connection, seller_tier: :tier)
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
        review_aggregates = Review
          .joins(:ad)
          .where(ads: { seller_id: seller_ids })
          .group("ads.seller_id")
          .select("ads.seller_id AS seller_id, COUNT(*) AS total, AVG(reviews.rating) AS avg_rating")
          .index_by { |r| r.seller_id.to_s }

        # Declared business categories/subcategories per seller (one bulk query)
        seller_categories = CategoriesSeller
          .where(seller_id: seller_ids)
          .pluck(:seller_id, :category_id, :subcategory_id)
          .each_with_object(Hash.new { |h, k| h[k] = { category_ids: [], subcategory_ids: [] } }) do |(sid, cid, scid), acc|
            acc[sid][:category_ids] << cid if cid
            acc[sid][:subcategory_ids] << scid if scid
          end

        sellers_data = sellers.map do |seller|
          branch = branch_coords[seller.id] || first_branches[seller.id]
          full_location = [branch&.location, seller.location].compact.map(&:strip).reject(&:blank?).uniq.join(', ')
          full_location = seller.location if full_location.blank?
          display_name = seller.enterprise_name.presence || seller.fullname.presence || 'Merchant'
          resolved_county = seller.county&.name.presence || 'Not Available'
          resolved_sub_county = seller.sub_county&.name.presence || 'Not Available'
          display_location = full_location.presence || seller.city.presence || 'Not Available'
          review_stats = review_aggregates[seller.id.to_s]
          cats = seller_categories[seller.id]
          google_reviews = seller.verified_google_reviews
          google_reviews_count = google_reviews.size
          google_average_rating = if google_reviews_count > 0
            (google_reviews.sum { |r| r["rating"].to_f } / google_reviews_count).round(1)
          else
            0.0
          end

          {
            id: seller.id,
            fullname: seller.fullname,
            slug: seller.url_slug,
            enterprise_name: display_name,
            location: display_location,
            branch_name: branch&.name,
            city: seller.city,
            county_name: resolved_county,
            sub_county_name: resolved_sub_county,
            latitude: branch&.latitude,
            longitude: branch&.longitude,
            location_precision: branch&.location_precision || 'approximate',
            phone_number: seller.phone_number,
            email: seller.email,
            profile_picture: seller.profile_picture,
            document_verified: seller.document_verified || false,
            ads_count: seller.ads_count,
            tier: seller.seller_tier&.tier&.name || 'Tier 1',
            total_reviews: review_stats&.total.to_i,
            average_rating: review_stats&.avg_rating.to_f.round(1),
            google_reviews_count: google_reviews_count,
            google_average_rating: google_average_rating,
            category_ids: cats[:category_ids].uniq,
            subcategory_ids: cats[:subcategory_ids].uniq
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
end
