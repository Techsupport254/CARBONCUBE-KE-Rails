# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base  
  include ExceptionHandler
  include ActivityTracking

  # Protect from CSRF for non-API endpoints
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  # Skip CSRF protection globally for API requests (in case you're building an API)
  skip_before_action :verify_authenticity_token, raise: false, if: -> { request.format.json? }
  
  # Add query timeout protection for database operations
  around_action :set_query_timeout
  around_action :track_request_performance
  
  # Log all requests for debugging (disabled)
  # before_action :log_all_requests

    # Optionally, you can uncomment the following for authentication
  # before_action :authenticate_request # Uncomment if needed for authentication

  attr_reader :current_user

  def home
    render json: { message: "API is up and running" }, status: :ok
  end

  def missing_file
    # Return a 404 for missing static files like images
    render json: { error: 'File not found' }, status: :not_found
  end

  # Block known bots/crawlers from tracking endpoints
  def block_bots
    if bot_request?
      render json: { error: 'Bot requests are not tracked' }, status: :forbidden
    end
  end

  # Detect known bots and crawlers by user agent
  def bot_request?
    user_agent = request.user_agent.to_s.downcase
    return false if user_agent.blank?

    bot_patterns = [
      'googlebot', 'bingbot', 'slurp', 'duckduckbot', 'baiduspider',
      'yandexbot', 'sogou', 'exabot', 'facebot', 'facebookexternalhit',
      'ia_archiver', 'twitterbot', 'linkedinbot', 'applebot',
      'whatsapp', 'telegrambot', 'discordbot', 'skypeuripreview',
      'semrush', 'ahrefsbot', 'mj12bot', 'dotbot', 'petalbot',
      'headlesschrome', 'phantomjs', 'selenium', 'wget', 'curl',
      'python-requests', 'scrapy', 'spider', 'crawl', 'bot/'
    ]

    bot_patterns.any? { |pattern| user_agent.include?(pattern) }
  end

  private

  def log_all_requests
    # Log ALL requests in development for debugging
    if Rails.env.development?
      Rails.logger.info "=" * 80
      Rails.logger.info "[ApplicationController] Request received"
      Rails.logger.info "   Timestamp: #{Time.current}"
      Rails.logger.info "   Method: #{request.method}"
      Rails.logger.info "   Path: #{request.path}"
      Rails.logger.info "   Full URL: #{request.url}"
      Rails.logger.info "   Query string: #{request.query_string}"
      Rails.logger.info "   Remote IP: #{request.remote_ip}"
      Rails.logger.info "   User-Agent: #{request.user_agent}"
      Rails.logger.info "   Referer: #{request.referer}"
      Rails.logger.info "   Content-Type: #{request.content_type}"
      Rails.logger.info "   Accept: #{request.headers['Accept']}"
      Rails.logger.info "   Origin: #{request.headers['Origin']}"
      Rails.logger.info "   Params keys: #{params.keys.inspect}"
      Rails.logger.info "   Params: #{params.except(:controller, :action).inspect}"
      Rails.logger.info "=" * 80
    end
  end

  def set_query_timeout
    # Set a reasonable query timeout for production
    ActiveRecord::Base.connection.execute("SET statement_timeout = '30s'")
    yield
  ensure
    # Reset to default timeout
    ActiveRecord::Base.connection.execute("SET statement_timeout = '60s'")
  end

  def authenticate_request
    @current_user = AuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end

  def json_response(object, status = :ok)
    render json: object, status: status
  end

  def track_request_performance
    start_time = Time.current
    yield
  ensure
    duration = Time.current - start_time
    MonitoringService.track_performance(
      controller_name,
      action_name,
      duration
    )
  end

  def track_error(exception)
    MonitoringService.track_error(exception, {
      controller: controller_name,
      action: action_name,
      user_id: current_user&.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      params: sanitize_params(params)
    })
  end

  def onboarding_ad_specifications
    raw = params.dig(:ad, :specifications) || {}

    specs =
      if raw.is_a?(String)
        begin
          parsed = JSON.parse(raw)
          parsed.is_a?(Hash) ? parsed : {}
        rescue JSON::ParserError
          {}
        end
      elsif raw.respond_to?(:permit)
        raw.permit(
          :pricing_unit, :price_display_mode, :price_range_max,
          price_tiers: [:min_quantity, :max_quantity, :unit_price, :label]
        ).to_unsafe_h
      elsif raw.is_a?(Hash)
        raw
      else
        {}
      end

    category = Category.find_by(id: params.dig(:ad, :category_id))
    is_service = category && Ad::SERVICE_CATEGORY_NAMES.any? { |name| category.name.to_s.downcase.include?(name.downcase) }
    allowed_units = is_service ? Ad::SERVICE_PRICING_UNITS : Ad::PRODUCT_PRICING_UNITS

    specs = specs.stringify_keys
    specs['pricing_unit'] = allowed_units.first unless allowed_units.include?(specs['pricing_unit'])
    unless %w[public tiered price_range request_quote].include?(specs['price_display_mode'])
      specs['price_display_mode'] = is_service ? 'price_range' : 'public'
    end
    specs['price_tiers'] = [] unless specs['price_tiers'].is_a?(Array)
    specs
  end

  private

  def sanitize_params(params)
    # Remove sensitive data from params before logging
    sanitized = params.except(:password, :password_confirmation, :token, :secret, :key)
    # Truncate long values to prevent log bloat
    sanitized.transform_values do |value|
      if value.is_a?(String) && value.length > 500
        "#{value[0..497]}..."
      else
        value
      end
    end
  end
end
