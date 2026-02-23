# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://carboncube-ke.com', 
            'https://www.carboncube-ke.com',
            'https://anko.carboncube-ke.com',
            'https://carboncube-ke.vercel.app',
            'http://localhost:3000',
            'http://localhost:3001'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose: ['Authorization', 'X-Request-Id', 'X-Runtime', 'X-Page-Load-Time'],
      max_age: 86400
  end
end
