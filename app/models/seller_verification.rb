class SellerVerification < ApplicationRecord
  belongs_to :seller
  belongs_to :sales_user

  OUTCOMES = %w[verified corrected not_found unreachable].freeze
  GPS_VERDICTS = %w[verified suspicious pending].freeze

  # Seller fields a rep is allowed to correct during a field visit.
  # Anything outside this list is ignored.
  CORRECTABLE_FIELDS = %w[
    enterprise_name
    phone_number
    location
    county_id
    sub_county_id
  ].freeze

  # Corrections to *_id fields resolve to record names in the audit trail.
  ID_FIELDS = %w[county_id sub_county_id].freeze

  VERIFIED_OUTCOMES = %w[verified corrected].freeze

  validates :outcome, inclusion: { in: OUTCOMES }
  validates :gps_verdict, inclusion: { in: GPS_VERDICTS }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_sales_user, ->(sales_user_id) { where(sales_user_id: sales_user_id) }
  scope :successful, -> { where(outcome: VERIFIED_OUTCOMES) }
  scope :with_corrections, -> { where.not(corrections: {}) }

  # Human-readable label for a correctable field (used in audit + UI).
  def self.field_label(field)
    {
      'enterprise_name' => 'Business name',
      'phone_number' => 'Phone number',
      'location' => 'Location',
      'county_id' => 'County',
      'sub_county_id' => 'Sub-county'
    }[field.to_s] || field.to_s.humanize
  end

  # Display value for an audit diff entry — resolves FK ids to record names.
  def self.display_value(field, value)
    return value if value.blank?

    case field.to_s
    when 'county_id'
      County.find_by(id: value)&.name || value
    when 'sub_county_id'
      SubCounty.find_by(id: value)&.name || value
    else
      value
    end
  end

  # Applies whitelisted corrections to the seller and returns the audit diff
  # ({ field => { 'old' => x, 'new' => y } }). Call inside a transaction —
  # raises ActiveRecord::RecordInvalid if the seller update fails validation.
  def self.build_corrections(seller, raw_corrections)
    return {} if raw_corrections.blank?

    diff = {}
    updates = {}

    raw_corrections.each do |field, new_value|
      field = field.to_s
      next unless CORRECTABLE_FIELDS.include?(field)

      new_value = new_value.to_s.strip
      next if new_value.blank?

      old_value = seller.public_send(field)
      next if new_value == old_value.to_s

      diff[field] = {
        'old' => display_value(field, old_value),
        'new' => display_value(field, new_value)
      }
      updates[field] = new_value
    end

    [diff, updates]
  end

  def corrected_fields
    corrections.keys
  end

  def corrected?
    corrections.present?
  end

  def successful?
    VERIFIED_OUTCOMES.include?(outcome)
  end

  # Compute distance evidence for this verification:
  # - distance_to_shop_km: rep GPS vs the seller's geocoded branch location
  # - nearest_ping_*: rep GPS vs the rep's own hourly pings today
  # Then derive gps_verdict.
  def assess_gps!
    return update!(gps_verdict: 'pending') if latitude.blank? || longitude.blank?

    branch = seller.branches.order(is_main_branch: :desc, id: :asc).first
    if branch&.latitude.present? && branch&.longitude.present?
      self.distance_to_shop_km = SellerCarbonCodeAssignment.haversine_distance(
        latitude.to_f, longitude.to_f, branch.latitude.to_f, branch.longitude.to_f
      )
    end

    assess_nearest_ping!

    self.gps_verdict =
      if distance_to_shop_km.present?
        distance_to_shop_km <= 5 ? 'verified' : 'suspicious'
      elsif nearest_ping_distance_km.present?
        nearest_ping_distance_km <= 5 ? 'verified' : 'suspicious'
      else
        'pending'
      end

    save!
  end

  private

  def assess_nearest_ping!
    return if sales_user_id.blank?

    date = (created_at || Time.current).to_date
    redis_pings = FieldLocationRedisService.fetch_pings(sales_user_id, date)
    db_pings = SalesUserFieldLocation.find_by(sales_user_id: sales_user_id, check_in_date: date)&.pings || []

    nearest_dist = nil
    nearest_ts = nil

    (redis_pings + db_pings).each do |ping|
      dist = SellerCarbonCodeAssignment.haversine_distance(
        latitude.to_f, longitude.to_f, ping['lat'] || ping[:lat], ping['lng'] || ping[:lng]
      )
      next if dist.nil? || (nearest_dist.present? && dist >= nearest_dist)

      nearest_dist = dist
      nearest_ts = ping['ts'] || ping[:ts]
    end

    self.nearest_ping_distance_km = nearest_dist
    self.nearest_ping_at = nearest_ts ? Time.zone.parse(nearest_ts) : nil
  end
end
