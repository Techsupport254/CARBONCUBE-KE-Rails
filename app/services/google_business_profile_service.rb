# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class GoogleBusinessProfileService
  ACCOUNT_MANAGEMENT_URL = 'https://mybusinessaccountmanagement.googleapis.com/v1/accounts'
  BUSINESS_INFORMATION_URL = 'https://mybusinessbusinessinformation.googleapis.com/v1'
  REVIEWS_URL = 'https://mybusiness.googleapis.com/v4'
  TOKEN_URL = 'https://oauth2.googleapis.com/token'
  SCOPE = 'https://www.googleapis.com/auth/business.manage'
  MAX_REVIEW_PAGES = 20

  class ConfigurationError < StandardError; end
  class ApiError < StandardError; end

  def self.configured?
    client_id.present? && client_secret.present? && redirect_uri.present?
  end

  def self.authorization_url(state)
    raise ConfigurationError, 'Google Business Profile is not configured' unless configured?

    uri = URI('https://accounts.google.com/o/oauth2/v2/auth')
    uri.query = URI.encode_www_form(
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: 'code',
      scope: SCOPE,
      access_type: 'offline',
      prompt: 'consent',
      state: state
    )
    uri.to_s
  end

  def self.exchange_code(code)
    response = post_form(TOKEN_URL, {
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      grant_type: 'authorization_code'
    })
    raise ApiError, response['error_description'] || 'Google authorization failed' if response['error'].present?

    response
  end

  def initialize(connection)
    @connection = connection
  end

  def locations
    accounts.flat_map do |account|
      account_id = account.fetch('name').split('/').last
      list_locations(account_id)
    end
  end

  def sync_reviews!
    raise ApiError, 'Choose a Business Profile location first' if @connection.google_account_id.blank? || @connection.google_location_id.blank?

    reviews = []
    page_token = nil
    MAX_REVIEW_PAGES.times do
      params = { pageSize: 50, orderBy: 'updateTime desc' }
      params[:pageToken] = page_token if page_token.present?
      response = get("#{REVIEWS_URL}/accounts/#{@connection.google_account_id}/locations/#{@connection.google_location_id}/reviews", params)
      reviews.concat(Array(response['reviews']).map { |review| normalize_review(review) })
      page_token = response['nextPageToken']
      break if page_token.blank?
    end

    average_rating = reviews.empty? ? nil : reviews.sum { |review| review['rating'] }.fdiv(reviews.size).round(2)
    @connection.update!(
      review_count: reviews.size,
      average_rating: average_rating,
      last_synced_at: Time.current,
      last_sync_error: nil,
      status: 'connected'
    )
    @connection.seller.update!(google_place_reviews: reviews, google_reviews_fetched_at: Time.current)
  rescue StandardError => e
    @connection.update_columns(status: 'error', last_sync_error: e.message, updated_at: Time.current)
    raise
  end

  private

  def accounts
    Array(get(ACCOUNT_MANAGEMENT_URL)['accounts'])
  end

  def list_locations(account_id)
    response = get(
      "#{BUSINESS_INFORMATION_URL}/accounts/#{account_id}/locations",
      readMask: 'name,title,storefrontAddress,metadata'
    )
    Array(response['locations']).map do |location|
      location_id = location.fetch('name').split('/').last
      {
        account_id: account_id,
        location_id: location_id,
        title: location['title'],
        address: Array(location.dig('storefrontAddress', 'addressLines')).join(', '),
        verification_state: location.dig('metadata', 'hasVoiceOfMerchant') ? 'verified' : 'unknown'
      }
    end
  end

  def get(url, params = {})
    token = valid_access_token
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.present?
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    parse_response(uri, request)
  end

  def valid_access_token
    return @connection.access_token if @connection.access_token.present? && @connection.access_token_expires_at&.>(1.minute.from_now)

    refresh_access_token
  end

  def refresh_access_token
    raise ApiError, 'Google authorization has expired. Reconnect your Business Profile.' if @connection.refresh_token.blank?

    response = self.class.send(:post_form, TOKEN_URL, {
      client_id: self.class.send(:client_id),
      client_secret: self.class.send(:client_secret),
      refresh_token: @connection.refresh_token,
      grant_type: 'refresh_token'
    })
    raise ApiError, response['error_description'] || 'Google token refresh failed' if response['error'].present?

    @connection.update!(
      access_token: response.fetch('access_token'),
      access_token_expires_at: response.fetch('expires_in').to_i.seconds.from_now,
      status: 'connected',
      last_sync_error: nil
    )
    @connection.access_token
  end

  def normalize_review(review)
    {
      'google_review_id' => review['reviewId'],
      'author_name' => review.dig('reviewer', 'displayName'),
      'profile_photo_url' => review.dig('reviewer', 'profilePhotoUrl'),
      'rating' => star_rating_value(review['starRating']),
      'text' => review['comment'],
      'time' => review['updateTime'],
      'review_reply' => review.dig('reviewReply', 'comment'),
      'review_reply_time' => review.dig('reviewReply', 'updateTime')
    }
  end

  def star_rating_value(value)
    { 'ONE' => 1, 'TWO' => 2, 'THREE' => 3, 'FOUR' => 4, 'FIVE' => 5 }.fetch(value, 0)
  end

  def parse_response(uri, request)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    body = JSON.parse(response.body.presence || '{}')
    return body if response.is_a?(Net::HTTPSuccess)

    raise ApiError, body.dig('error', 'message') || "Google Business Profile request failed (#{response.code})"
  rescue JSON::ParserError
    raise ApiError, 'Google Business Profile returned an invalid response'
  end

  class << self
    private

    def post_form(url, params)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(params)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body.presence || '{}')
    rescue JSON::ParserError
      raise ApiError, 'Google authorization returned an invalid response'
    end

    def client_id
      ENV['GOOGLE_BUSINESS_PROFILE_CLIENT_ID'].presence || ENV['GOOGLE_OAUTH_CLIENT_ID'].presence
    end

    def client_secret
      ENV['GOOGLE_BUSINESS_PROFILE_CLIENT_SECRET'].presence || ENV['GOOGLE_OAUTH_CLIENT_SECRET'].presence
    end

    def redirect_uri
      ENV['GOOGLE_BUSINESS_PROFILE_REDIRECT_URI'].presence
    end
  end
end
