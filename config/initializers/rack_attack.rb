# Rack::Attack configuration
class Rack::Attack
  # Disable rack-attack by default
  # You can enable specific throttles as needed
  
  # Example configuration (disabled):
  # throttle('requests by ip', limit: 300, period: 5.minutes) do |request|
  #   request.ip
  # end
end
