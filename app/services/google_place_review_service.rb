# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class GooglePlaceReviewService
  GOOGLE_PLACES_BASE = 'https://maps.googleapis.com/maps/api/place'
  REVIEW_FIELDS = 'reviews,rating,user_ratings_total'

  # Kenyan geographical bounding box
  KENYA_LAT_RANGE = (-4.8..5.0)
  KENYA_LNG_RANGE = (33.8..42.0)

  GENERIC_EMAIL_DOMAINS = %w[
    gmail.com yahoo.com outlook.com hotmail.com icloud.com
    mail.com protonmail.com aol.com live.com ymail.com
  ].freeze

  # Words that make a business name or address non-distinctive.
  GENERIC_NAME_WORDS = %w[
    auto spares spare parts mobile phone shop store services service solutions
    supplies supply motors motor electronics computer computers plumbing plumber
    furniture supermarket trading company co limited ltd enterprise enterprises
    kenya ke inc and nairobi cbd road rd street st avenue ave lane ln drive dr
    town ward county building plaza centre center mall market bus stop stage
    hospital clinic school church hotel restaurant cafe bar pharmacy electricals
    electrical hardware hardwares tv stands stand food grocery home goods
    electronics_store
  ].freeze

  # Place types that should never be treated as a business.
  NON_BUSINESS_TYPES = %w[
    locality political country administrative_area_level_1 administrative_area_level_2
    administrative_area_level_3 administrative_area_level_4 administrative_area_level_5
    sublocality neighborhood postal_code route street_address premise subpremise
    colloquial_area geocode plus_code natural_feature airport campground park
    transit_station train_station subway_station bus_station light_rail_station
    taxi_stand
  ].freeze

  def initialize(seller)
    @seller = seller
    @api_key = ENV.fetch('GOOGLE_MAPS_API_KEY')
  end

  # DEPRECATED: Google Places API heuristic matching is retired in favor of
  # owner-authorized Google Business Profile integration (GoogleBusinessProfileService).
  # Automatic resolution via text search frequently matched unrelated businesses with wrong reviews.
  def sync!
    Rails.logger.warn(
      "GooglePlaceReviewService is deprecated. Use GoogleBusinessProfileService for seller #{@seller.id} instead."
    )
    false
  end

  private

  def place_still_valid?
    place = place_details(@seller.google_place_id,
                          'name,formatted_address,types,formatted_phone_number,' \
                          'international_phone_number,website,business_status,geometry')
    valid_place?(place)
  rescue StandardError => e
    Rails.logger.warn("Google Place validation failed for seller #{@seller.id}: #{e.message}")
    false
  end

  def resolve_place_id
    place_id = resolve_by_phone(@seller.phone_number)
    place_id ||= resolve_by_phone(@seller.secondary_phone_number)
    place_id ||= resolve_by_custom_email(@seller.email)
    place_id ||= resolve_by_text_search

    return if place_id.blank?

    @seller.update!(
      google_place_id: place_id,
      google_place_id_fetched_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Google Place ID resolution failed for seller #{@seller.id}: #{e.message}")
  end

  def resolve_by_phone(phone)
    return nil if phone.blank?

    formatted_phone = format_kenyan_phone(phone)
    return nil if formatted_phone.blank?

    response = request('/findplacefromtext/json', {
                         input: formatted_phone,
                         inputtype: 'phonenumber',
                         fields: 'place_id,name,formatted_address,geometry,types,' \
                                 'formatted_phone_number,international_phone_number,website,business_status'
                       })
    candidate = response['candidates']&.first
    return nil unless valid_place?(candidate)

    candidate['place_id']
  end

  def resolve_by_custom_email(email)
    domain = email.to_s.split('@').last.to_s.downcase.strip
    return nil if domain.blank? || GENERIC_EMAIL_DOMAINS.include?(domain)

    response = request('/findplacefromtext/json', {
                         input: email.strip,
                         inputtype: 'textquery',
                         fields: 'place_id,name,formatted_address,geometry,types,' \
                                 'formatted_phone_number,international_phone_number,website,business_status'
                       })
    candidate = response['candidates']&.first
    return nil unless valid_place?(candidate)

    candidate['place_id']
  end

  def resolve_by_text_search
    return nil if @seller.enterprise_name.blank?

    query_parts = [@seller.enterprise_name, @seller.location, @seller.city, 'Kenya'].compact_blank.map(&:strip)
    query = query_parts.join(' ').strip
    return nil if query.blank?

    params = {
      query: query,
      region: 'ke'
    }

    branch = @seller.branches.first
    if branch&.latitude.present? && branch&.longitude.present?
      params[:location] = "#{branch.latitude},#{branch.longitude}"
      params[:radius] = 25_000 # 25 km
    end

    response = request('/textsearch/json', params)
    candidates = Array(response['results'])
    return nil if candidates.empty?

    valid_candidates = candidates.select { |cand| inside_kenya?(cand) && !non_business_place?(cand) }
    return nil if valid_candidates.empty?

    sorted = valid_candidates.sort_by { |cand| -text_search_score(cand) }
    sorted.first(5).each do |candidate|
      place = place_details(candidate['place_id'],
                            'name,formatted_address,types,formatted_phone_number,' \
                            'international_phone_number,website,business_status,geometry')
      return place['place_id'] if valid_place?(place)
    end

    nil
  end

  def valid_place?(place)
    return false if place.blank?
    return false unless inside_kenya?(place)
    return false if non_business_place?(place)
    return true if phone_matches?(place)
    return true if website_matches_email?(place)
    return false unless concrete_business?(place)
    return false unless strong_name_match?(place)

    address_or_branch_matches?(place)
  end

  def concrete_business?(place)
    types = Array(place['types']) - %w[establishment point_of_interest]
    types.any?
  end

  def place_details(place_id, fields)
    response = request('/details/json', {
                         place_id: place_id,
                         fields: fields
                       })
    response['result']
  end

  def non_business_place?(place)
    types = Array(place['types'])
    types.any? { |type| NON_BUSINESS_TYPES.include?(type) }
  end

  def phone_matches?(place)
    return false if @seller.phone_number.blank?

    seller_digits = last_nine_digits(@seller.phone_number)
    return false if seller_digits.blank?

    place_phones = [place['formatted_phone_number'], place['international_phone_number']].compact
    place_phones.any? { |phone| last_nine_digits(phone) == seller_digits }
  end

  def website_matches_email?(place)
    return false if place['website'].blank? || @seller.email.blank?

    seller_domain = email_domain(@seller.email)
    return false if seller_domain.blank? || GENERIC_EMAIL_DOMAINS.include?(seller_domain)

    place_domain = URI.parse(place['website']).host.to_s.downcase.gsub(/^www\./, '')
    place_domain == seller_domain || place_domain.end_with?(".#{seller_domain}")
  rescue URI::InvalidURIError
    false
  end

  def strong_name_match?(place)
    return false if @seller.enterprise_name.blank? || place['name'].blank?

    similarity = calculate_name_similarity(@seller.enterprise_name, place['name'])
    similarity >= 0.85
  end

  def address_or_branch_matches?(place)
    return true if branch_distance_km(place) <= 1.0
    return false if @seller.location.blank?

    location_tokens = distinctive_tokens(@seller.location)
    return false if location_tokens.empty?

    address = place['formatted_address'].to_s.downcase
    location_tokens.any? { |token| address.include?(token) }
  end

  def text_search_score(candidate)
    name_score = calculate_name_similarity(@seller.enterprise_name, candidate['name'])
    distance_score = branch_distance_score(candidate)
    address_score = address_token_score(candidate)

    (name_score * 2) + distance_score + address_score
  end

  def branch_distance_score(candidate)
    distance = branch_distance_km(candidate)
    return 0.0 if distance.infinite?

    if distance <= 2.0
      2.0
    elsif distance <= 10.0
      1.0
    else
      0.0
    end
  end

  def address_token_score(candidate)
    score = 0.0
    address = candidate['formatted_address'].to_s.downcase

    if @seller.city.present?
      city_tokens = distinctive_tokens(@seller.city)
      score += 0.5 if city_tokens.any? { |token| address.include?(token) }
    end

    if @seller.county&.name.present?
      county_tokens = distinctive_tokens(@seller.county.name)
      score += 0.5 if county_tokens.any? { |token| address.include?(token) }
    end

    if @seller.location.present?
      location_tokens = distinctive_tokens(@seller.location)
      score += 1.0 if location_tokens.any? { |token| address.include?(token) }
    end

    score
  end

  def branch_distance_km(place)
    branch = @seller.branches.first
    return Float::INFINITY if branch&.latitude.blank? || branch&.longitude.blank?

    lat = place.dig('geometry', 'location', 'lat')
    lng = place.dig('geometry', 'location', 'lng')
    return Float::INFINITY if lat.nil? || lng.nil?

    SellerCarbonCodeAssignment.haversine_distance(branch.latitude, branch.longitude, lat, lng)
  end

  def calculate_name_similarity(str1, str2)
    tokens1 = distinctive_tokens(str1)
    tokens2 = distinctive_tokens(str2)
    return 1.0 if tokens1 == tokens2
    return 0.0 if tokens1.empty? || tokens2.empty?

    joined1 = tokens1.join
    joined2 = tokens2.join
    return 0.95 if joined1.include?(joined2) || joined2.include?(joined1)

    intersection = (tokens1 & tokens2).size
    union = (tokens1 | tokens2).size
    return 0.0 if union.zero?

    intersection.to_f / union
  end

  def distinctive_tokens(text)
    normalize_for_comparison(text).split - GENERIC_NAME_WORDS
  end

  def normalize_for_comparison(text)
    text.to_s.downcase
        .gsub(/[^a-z0-9\s]/, ' ')
        .squeeze(' ')
        .strip
  end

  def inside_kenya?(candidate)
    addr = candidate['formatted_address'].to_s.downcase
    return true if addr.include?('kenya')

    lat = candidate.dig('geometry', 'location', 'lat')
    lng = candidate.dig('geometry', 'location', 'lng')
    return false if lat.nil? || lng.nil?

    KENYA_LAT_RANGE.cover?(lat) && KENYA_LNG_RANGE.cover?(lng)
  end

  def last_nine_digits(phone)
    digits = phone.to_s.gsub(/\D/, '')
    return nil if digits.length < 9

    digits[-9..]
  end

  def email_domain(email)
    email.to_s.split('@').last.to_s.downcase.strip
  end

  def fetch_reviews
    response = request('/details/json', {
                         place_id: @seller.google_place_id,
                         fields: REVIEW_FIELDS
                       })
    result = response['result']
    return if result.blank?

    @seller.update!(
      google_place_reviews: result['reviews'] || [],
      google_reviews_fetched_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Google reviews fetch failed for seller #{@seller.id}: #{e.message}")
  end

  def request(path, params = {})
    uri = URI("#{GOOGLE_PLACES_BASE}#{path}")
    uri.query = URI.encode_www_form(params.merge(key: @api_key))
    response = Net::HTTP.get_response(uri)

    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def format_kenyan_phone(phone)
    digits = phone.to_s.gsub(/\D/, '')
    return nil if digits.blank?

    if digits.start_with?('0') && digits.length == 10
      "+254#{digits[1..]}"
    elsif digits.start_with?('254') && digits.length == 12
      "+#{digits}"
    elsif digits.length == 9
      "+254#{digits}"
    elsif digits.length >= 9
      "+254#{digits[-9..]}"
    end
  end
end
