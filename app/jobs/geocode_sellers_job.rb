class GeocodeSellersJob < ApplicationJob
  queue_as :default

  NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search"
  RATE_LIMIT_DELAY = 1 # seconds between requests (OSM requires max 1 request per second)

  def perform(seller_id = nil)
    # Find sellers without coordinates in their branches
    sellers_without_coords = Seller
      .joins(:branches)
      .where(branches: { latitude: nil })
      .where.not(sellers: { location: nil })
    sellers_without_coords = sellers_without_coords.where(id: seller_id) if seller_id.present?
    sellers_without_coords = sellers_without_coords.distinct.limit(700) # Process all sellers in one batch (rate limited at 1 req/s)

    Rails.logger.info "Starting geocoding for #{sellers_without_coords.count} sellers"

    sellers_without_coords.each_with_index do |seller, index|
      begin
        # Rate limiting
        sleep(RATE_LIMIT_DELAY) if index > 0

        # Geocode the seller's location
        coordinates = geocode_location(seller)

        if coordinates
          # Update the seller's branch with coordinates
          seller.branches.each do |branch|
            branch.update(
              latitude: coordinates[:lat],
              longitude: coordinates[:lon]
            )
          end
          
          Rails.logger.info "Successfully geocoded seller: #{seller.enterprise_name} (#{seller.location})"
        else
          Rails.logger.warn "Failed to geocode seller: #{seller.enterprise_name} (#{seller.location})"
        end
      rescue => e
        Rails.logger.error "Error geocoding seller #{seller.id}: #{e.message}"
      end
    end

    Rails.logger.info "Geocoding job completed"
  end

  private

  def geocode_location(seller)
    # Build the query string from available location data
    query_parts = []
    
    query_parts << seller.location if seller.location.present?
    query_parts << seller.city if seller.city.present?
    query_parts << seller.county&.name if seller.county.present?
    query_parts << "Kenya" # Add country for better accuracy

    query = query_parts.join(", ")

    # Call OpenStreetMap Nominatim API with required User-Agent header
    uri = URI(NOMINATIM_API_URL)
    params = {
      q: query,
      format: 'json',
      limit: 1,
      addressdetails: 1
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'CarbonCube-Kenya/1.0 (contact: info@carboncube-ke.com)'
    request['Accept'] = 'application/json'

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      
      if data.any?
        return {
          lat: data.first['lat'].to_f,
          lon: data.first['lon'].to_f
        }
      end
    end

    nil
  end
end
