class SocialMediaCrawlerMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Check if this is a social media crawler
    user_agent = request.user_agent.to_s.downcase
    
    social_crawlers = [
      'facebookexternalhit',
      'facebookcatalog',
      'twitterbot',
      'linkedinbot',
      'whatsapp',
      'telegrambot',
      'slackbot',
      'discordbot',
      'skypeuripreview',
      'applebot',
      'googlebot',
      'bingbot'
    ]
    
    is_social_crawler = social_crawlers.any? { |crawler| user_agent.include?(crawler) }
    
    # Check if this is a shop or ad page
    path = request.path
    
    if is_social_crawler && (path.match?(/^\/shop\/[^\/]+$/) || path.match?(/^\/ads\/\d+$/))
      # Extract slug or ad_id
      if path.match?(/^\/shop\/([^\/]+)$/)
        slug = $1
        # Redirect to meta tag API
        return [302, { 'Location' => "/api/meta/shop/#{slug}" }, []]
      elsif path.match?(/^\/ads\/(\d+)$/)
        ad_id = $1
        # Redirect to meta tag API
        return [302, { 'Location' => "/api/meta/ad/#{ad_id}" }, []]
      end
    end
    
    # For non-crawlers or other paths, continue normally
    @app.call(env)
  end
end
