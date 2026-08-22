# frozen_string_literal: true

class GooglePlaceReviewService
  GOOGLE_PLACES_BASE = "https://maps.googleapis.com/maps/api/place"
  REVIEW_FIELDS = "reviews,rating,user_ratings_total"

  def initialize(seller)
    @seller = seller
    @api_key = ENV.fetch("GOOGLE_MAPS_API_KEY")
  end

  def sync!
    resolve_place_id if @seller.google_place_id.blank?
    fetch_reviews if @seller.google_place_id.present?
  end

  private

  def resolve_place_id
    query = [@seller.enterprise_name, @seller.city].compact.join(" ").strip
    return if query.blank?

    response = request("/textsearch/json", query: query)
    result = response["results"]&.first
    return if result.blank?

    @seller.update!(
      google_place_id: result["place_id"],
      google_place_id_fetched_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Google Place ID resolution failed for seller #{@seller.id}: #{e.message}")
  end

  def fetch_reviews
    response = request("/details/json", place_id: @seller.google_place_id, fields: REVIEW_FIELDS)
    result = response["result"]
    return if result.blank?

    @seller.update!(
      google_place_reviews: result["reviews"] || [],
      google_reviews_fetched_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Google reviews fetch failed for seller #{@seller.id}: #{e.message}")
  end

  def request(path, params)
    uri = URI("#{GOOGLE_PLACES_BASE}#{path}")
    uri.query = URI.encode_www_form(params.merge(key: @api_key))
    response = Net::HTTP.get_response(uri)

    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
