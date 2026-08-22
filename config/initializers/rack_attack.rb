# Rack::Attack configuration
class Rack::Attack
  # Throttle all requests by IP: 300 requests per 5 minutes
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle authentication attempts: 10 per minute per IP
  throttle('auth/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/auth/')
  end

  # Throttle public search/listing endpoints that are expensive
  throttle('ads/ip', limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/ads') || req.path.start_with?('/buyer/ads')
  end
end
