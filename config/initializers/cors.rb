# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allowed_origins = [
    'https://carboncube-ke.com',
    'https://www.carboncube-ke.com',
    'https://anko.carboncube-ke.com',
    'https://carboncube-ke.vercel.app',
    'http://localhost:3000',
    'http://localhost:3001',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:3001',
    'http://localhost:5173',
    'http://127.0.0.1:5173'
  ]

  # Optional comma-separated custom origins for temporary web environments.
  # Example: CORS_ADDITIONAL_ORIGINS=https://staging.example.com,https://foo.example.com
  env_origins = ENV.fetch('CORS_ADDITIONAL_ORIGINS', '')
                   .split(',')
                   .map(&:strip)
                   .reject(&:blank?)

  allow do
    origins(*allowed_origins, *env_origins, %r{\Ahttps://.*\.vercel\.app\z})

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization', 'X-Request-Id', 'X-Runtime', 'X-Page-Load-Time'],
      max_age: 86400
  end
end
