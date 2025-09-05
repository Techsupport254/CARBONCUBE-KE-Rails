class ShopsController < ApplicationController
  def show
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    # Convert slug back to enterprise name format for searching
    # Replace hyphens with spaces and handle special characters
    enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
    
    # First try exact match with case insensitive
    @shop = Seller.includes(:seller_tier, :tier)
                  .where(deleted: false)
                  .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
                  .first
    
    # If no exact match, try partial match
    unless @shop
      @shop = Seller.includes(:seller_tier, :tier)
                    .where(deleted: false)
                    .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                    .first
    end
    
    # If still no match, try to find by ID as fallback (for backward compatibility)
    unless @shop
      begin
        shop_id = slug.to_i
        if shop_id > 0
          @shop = Seller.includes(:seller_tier, :tier)
                        .where(deleted: false)
                        .find(shop_id)
        end
      rescue ActiveRecord::RecordNotFound
        # Ignore and continue to error handling
      end
    end
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    # Check if this is a social media crawler
    if social_media_crawler?
      # Serve HTML with meta tags for social media crawlers
      render_html_for_crawler
      return
    end
    
    # Get shop's active ads with pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    
    @ads = @shop.ads
                .active
                .where(flagged: false)
                .joins(:category, :subcategory, seller: { seller_tier: :tier })
                .left_joins(:reviews)
                .includes(:category, :subcategory, :reviews, seller: { seller_tier: :tier })
                .order('tiers.id DESC, ads.created_at DESC')
                .offset((page - 1) * per_page)
                .limit(per_page)
    
    # Get total count for pagination
    @total_count = @shop.ads.active.where(flagged: false).count
    
    render json: {
      shop: {
        id: @shop.id,
        enterprise_name: @shop.enterprise_name,
        description: @shop.description,
        email: @shop.email,
        address: @shop.location,
        profile_picture: @shop.profile_picture,
        tier: @shop.seller_tier&.tier&.name || 'Free',
        tier_id: @shop.seller_tier&.tier&.id || 1,
        product_count: @total_count,
        created_at: @shop.created_at
      },
      ads: @ads.map { |ad| AdSerializer.new(ad).as_json },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: @total_count,
        total_pages: (@total_count.to_f / per_page).ceil
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shop not found' }, status: :not_found
  end

  def reviews
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    # Convert slug back to enterprise name format for searching
    enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
    
    # First try exact match with case insensitive
    @shop = Seller.includes(:seller_tier, :tier)
                  .where(deleted: false)
                  .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
                  .first
    
    # If no exact match, try partial match
    unless @shop
      @shop = Seller.includes(:seller_tier, :tier)
                    .where(deleted: false)
                    .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                    .first
    end
    
    # If still no match, try to find by ID as fallback
    unless @shop
      begin
        shop_id = slug.to_i
        if shop_id > 0
          @shop = Seller.includes(:seller_tier, :tier)
                        .where(deleted: false)
                        .find(shop_id)
        end
      rescue ActiveRecord::RecordNotFound
        # Ignore and continue to error handling
      end
    end
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    # Get pagination parameters
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 10
    
    # Get all reviews for this shop's ads
    @reviews = Review.joins(:ad)
                     .where(ads: { seller_id: @shop.id })
                     .includes(:buyer, :ad)
                     .order(created_at: :desc)
                     .offset((page - 1) * per_page)
                     .limit(per_page)
    
    # Calculate review statistics
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count
    average_rating = total_reviews > 0 ? all_reviews.average(:rating).round(1) : 0
    
    # Rating distribution
    rating_distribution = (1..5).map do |rating|
      count = all_reviews.where(rating: rating).count
      percentage = total_reviews > 0 ? (count.to_f / total_reviews * 100).round(1) : 0
      { rating: rating, count: count, percentage: percentage }
    end
    
    # Format reviews data
    reviews_data = @reviews.map do |review|
      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        seller_reply: review.seller_reply,
        created_at: review.created_at,
        updated_at: review.updated_at,
        buyer: {
          id: review.buyer.id,
          name: review.buyer.fullname || review.buyer.name || "Buyer ##{review.buyer.id}"
        },
        ad: {
          id: review.ad.id,
          title: review.ad.title,
          price: review.ad.price
        }
      }
    end
    
    render json: {
      reviews: reviews_data,
      statistics: {
        total_reviews: total_reviews,
        average_rating: average_rating,
        rating_distribution: rating_distribution
      },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_reviews,
        total_pages: (total_reviews.to_f / per_page).ceil
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shop not found' }, status: :not_found
  end

  private

  def social_media_crawler?
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
    
    social_crawlers.any? { |crawler| user_agent.include?(crawler) }
  end

  def render_html_for_crawler
    # Generate shop-specific meta tags
    title = "#{@shop.enterprise_name} Shop - #{@shop.ads.active.count} Products | Carbon Cube Kenya"
    description = @shop.description.presence || "#{@shop.enterprise_name} - #{@shop.seller_tier&.tier&.name || 'Free'} seller offering #{@shop.ads.active.count} quality products for online shopping on Carbon Cube Kenya"
    
    # Use shop profile picture or fallback
    image_url = if @shop.profile_picture.present?
      if @shop.profile_picture.start_with?('http')
        @shop.profile_picture
      else
        "https://carboncube-ke.com#{@shop.profile_picture}"
      end
    else
      "https://via.placeholder.com/1200x630/FFD700/000000?text=#{CGI.escape(@shop.enterprise_name)}"
    end
    
    url = "https://carboncube-ke.com/shop/#{params[:slug]}"
    
    # Return HTML with meta tags for social media crawlers
    html_content = generate_meta_html(title, description, image_url, url, "website")
    render html: html_content.html_safe
  end

  def generate_meta_html(title, description, image_url, url, type)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>#{title}</title>
        <meta name="description" content="#{description}">
        
        <!-- Open Graph / Facebook -->
        <meta property="og:type" content="#{type}">
        <meta property="og:url" content="#{url}">
        <meta property="og:site_name" content="Carbon Cube Kenya">
        <meta property="og:title" content="#{title}">
        <meta property="og:description" content="#{description}">
        <meta property="og:image" content="#{image_url}">
        <meta property="og:image:width" content="1200">
        <meta property="og:image:height" content="630">
        <meta property="og:locale" content="en_US">
        <meta property="og:image:alt" content="#{title}">
        
        <!-- Twitter Card -->
        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:site" content="@carboncube_kenya">
        <meta name="twitter:title" content="#{title}">
        <meta name="twitter:description" content="#{description}">
        <meta name="twitter:image" content="#{image_url}">
        <meta name="twitter:image:alt" content="#{title}">
        
        <!-- Redirect to actual page -->
        <meta http-equiv="refresh" content="0; url=#{url}">
        <script>window.location.href = "#{url}";</script>
      </head>
      <body>
        <p>Redirecting to <a href="#{url}">#{url}</a>...</p>
      </body>
      </html>
    HTML
  end
end
