class Rack::Attack
  class << self
    def real_ip(req)
      forwarded = req.env["HTTP_X_FORWARDED_FOR"]
      return forwarded.split(",").map(&:strip).first if forwarded

      req.env["HTTP_X_REAL_IP"] || req.ip
    end
  end

  # Don't rate-limit health checks or uptime endpoints
  safelist("allow/health") do |req|
    req.path.start_with?("/health", "/up", "/rails/health")
  end

  # Authentication: brute-force protection (login, oauth, reactivation, etc.)
  throttle("auth/ip", limit: 10, period: 1.minute) do |req|
    Rack::Attack.real_ip(req) if req.post? && req.path.start_with?("/auth/")
  end

  # Account enumeration endpoints (email/username/phone/business checks)
  throttle("account/exists", limit: 30, period: 1.minute) do |req|
    Rack::Attack.real_ip(req) if req.path.match?(%r{\A/(email|username|phone|business_name|business_number)/exists\z}) ||
                                 req.path.match?(%r{\A/(check|validate)_(email|username|phone)\z})
  end

  # Contact form spam
  throttle("contact/submit", limit: 5, period: 1.minute) do |req|
    Rack::Attack.real_ip(req) if req.post? && req.path == "/contact/submit"
  end

  # Data-deletion requests
  throttle("data_deletion/request", limit: 3, period: 1.hour) do |req|
    Rack::Attack.real_ip(req) if req.post? && req.path == "/data_deletion/request"
  end

  # Expensive geocoding / batch operations
  throttle("geocoding", limit: 30, period: 1.minute) do |req|
    Rack::Attack.real_ip(req) if req.path.start_with?("/geocoding/") || req.path == "/seller/geocode-batch"
  end

  # Image proxy that fetches external URLs
  throttle("proxy-image", limit: 60, period: 1.minute) do |req|
    Rack::Attack.real_ip(req) if req.path == "/proxy-image"
  end

  # Catch-all for the rest of the API
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    Rack::Attack.real_ip(req)
  end
end
