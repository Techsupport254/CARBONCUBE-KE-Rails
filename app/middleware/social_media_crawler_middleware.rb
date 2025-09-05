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
      'whatsappbot',
      'whatsapp/',
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
    
    if is_social_crawler && path.match?(/^\/ads\/\d+$/)
      # Extract ad_id
      ad_id = path.match(/^\/ads\/(\d+)$/)[1]
      # Redirect to meta tag API
      return [302, { 'Location' => "/meta/ad/#{ad_id}" }, []]
    end
    
    # For non-crawlers or other paths, continue normally
    @app.call(env)
  end
end
