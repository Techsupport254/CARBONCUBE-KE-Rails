class SellerCarbonCodeAssignment < ApplicationRecord
  belongs_to :seller
  belongs_to :carbon_code
  belongs_to :sales_user, optional: true

  # Sales user's GPS (if they manually assigned the code — rare case)
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  # Seller's GPS (captured from seller's phone during self-registration — common case)
  validates :seller_gps_latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :seller_gps_longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  # Haversine distance (in km) between two lat/lng points
  def self.haversine_distance(lat1, lng1, lat2, lng2)
    return nil if [lat1, lng1, lat2, lng2].any?(&:blank?)

    rad_per_deg = Math::PI / 180
    earth_radius_km = 6371

    dlat = (lat2 - lat1) * rad_per_deg
    dlng = (lng2 - lng1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) * Math.sin(dlng / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    (earth_radius_km * c).round(2)
  end

  # Cross-reference this assignment with the sales user's hourly pings.
  # Finds the nearest ping to the seller's GPS location and stores the distance.
  # Called after a seller self-registers with a carbon code.
  def cross_reference_pings!
    return if seller_gps_latitude.blank? || sales_user_id.blank?

    date = created_at.to_date
    redis_pings = FieldLocationRedisService.fetch_pings(sales_user_id, date)
    db_record = SalesUserFieldLocation.find_by(sales_user_id: sales_user_id, check_in_date: date)
    db_pings = db_record&.pings || []

    all_pings = redis_pings + db_pings

    nearest = nil
    nearest_dist = nil

    all_pings.each do |ping|
      ping_lat = ping['lat'] || ping[:lat]
      ping_lng = ping['lng'] || ping[:lng]
      next if ping_lat.blank? || ping_lng.blank?

      dist = self.class.haversine_distance(seller_gps_latitude, seller_gps_longitude, ping_lat, ping_lng)
      next if dist.nil?

      if nearest_dist.nil? || dist < nearest_dist
        nearest_dist = dist
        nearest = ping
      end
    end

    if nearest
      ping_ts = nearest['ts'] || nearest[:ts]
      update!(
        nearest_ping_distance_km: nearest_dist,
        nearest_ping_at: ping_ts ? Time.parse(ping_ts) : nil
      )
    end

    nearest_dist
  end
end
