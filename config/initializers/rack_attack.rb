require "ipaddr"

class Rack::Attack
  PRIVATE_NETWORKS = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("::1/128")
  ].freeze

  class << self
    def real_ip(req)
      forwarded = req.env["HTTP_X_FORWARDED_FOR"]
      return forwarded.split(",").map(&:strip).first if forwarded

      req.env["HTTP_X_REAL_IP"] || req.ip
    end

    def private_ip?(ip)
      return false unless ip
      return true if %w[127.0.0.1 ::1].include?(ip)

      IPAddr.new(ip)
      PRIVATE_NETWORKS.any? { |net| net.include?(ip) }
    rescue IPAddr::InvalidAddressError
      false
    end
  end

  # Don't rate-limit health checks or uptime endpoints
  safelist("allow/health") do |req|
    req.path.start_with?("/health", "/up", "/rails/health")
  end

  # Don't rate-limit internal/private network traffic (Dokploy/Docker builds, SSG)
  safelist("allow/private-networks") do |req|
    Rack::Attack.private_ip?(Rack::Attack.real_ip(req))
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
