class ShopMetaController < ApplicationController
  def show
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
      render html: "<html><head><title>Shop Not Found</title></head><body><h1>Shop Not Found</h1></body></html>".html_safe, status: :not_found
      return
    end
    
    # Calculate review statistics
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count
    average_rating = total_reviews > 0 ? all_reviews.average(:rating).round(1) : 0
    
    # Get shop categories
    shop_categories = @shop.categories.pluck(:name).join(', ')
    
    # Generate meta tags data
    location = [@shop.city, @shop.sub_county&.name, @shop.county&.name].compact.join(', ')
    tier = @shop.seller_tier&.tier&.name || 'Free'
    product_count = @shop.ads.active.where(flagged: false).count
    
    # Generate title
    title = "#{@shop.enterprise_name} - Shop | #{product_count} Products | #{tier} Tier Seller"
    
    # Generate description
    rating_text = average_rating > 0 ? " Rated #{average_rating}/5 stars" : ""
    reviews_text = total_reviews > 0 ? " with #{total_reviews} reviews" : ""
    location_text = location.present? ? " in #{location}" : ""
    
    description = if @shop.description.present?
      "#{@shop.description[0..160]}... Shop #{@shop.enterprise_name} on Carbon Cube Kenya. #{product_count} products available from #{tier} tier verified seller#{location_text}.#{rating_text}#{reviews_text}. Fast delivery across Kenya."
    else
      "Shop #{@shop.enterprise_name} on Carbon Cube Kenya. #{product_count} products available from #{tier} tier verified seller#{location_text}.#{rating_text}#{reviews_text}. Browse quality products with fast delivery across Kenya."
    end
    
    # Generate keywords
    keywords = [
      @shop.enterprise_name,
      "#{@shop.enterprise_name} shop",
      "#{@shop.enterprise_name} store",
      shop_categories,
      @shop.city,
      @shop.county&.name,
      @shop.sub_county&.name,
      "#{tier} tier seller",
      "online shop Kenya",
      "Carbon Cube Kenya",
      "Kenya marketplace",
      "#{product_count} products",
      @shop.business_registration_number.present? ? "registered business #{@shop.business_registration_number}" : nil,
      "Kenya e-commerce",
      "online shopping Kenya",
      "verified seller Kenya"
    ].compact.join(', ')
    
    # Generate image URL
    image_url = if @shop.profile_picture.present?
      if @shop.profile_picture.start_with?('http')
        @shop.profile_picture
      elsif @shop.profile_picture.start_with?('/')
        "https://carboncube-ke.com#{@shop.profile_picture}"
      else
        @shop.profile_picture
      end
    else
      "https://via.placeholder.com/1200x630/FFD700/000000?text=#{CGI.escape("#{@shop.enterprise_name} - Carbon Cube Kenya")}"
    end
    
    # Generate URL
    shop_url = "https://carboncube-ke.com/shop/#{slug}"
    
    # Generate structured data
    structured_data = {
      "@context": "https://schema.org",
      "@type": "LocalBusiness",
      "name": @shop.enterprise_name,
      "description": @shop.description || "Shop #{@shop.enterprise_name} on Carbon Cube Kenya",
      "url": shop_url,
      "image": image_url,
      "address": @shop.location.present? ? {
        "@type": "PostalAddress",
        "streetAddress": @shop.location,
        "addressLocality": @shop.city || "Kenya",
        "addressRegion": @shop.county&.name || "Kenya",
        "addressCountry": "KE"
      } : nil,
      "telephone": @shop.phone_number,
      "email": @shop.email,
      "aggregateRating": total_reviews > 0 ? {
        "@type": "AggregateRating",
        "ratingValue": average_rating,
        "reviewCount": total_reviews,
        "bestRating": 5,
        "worstRating": 1
      } : nil,
      "priceRange": "$$",
      "currenciesAccepted": "KES",
      "paymentAccepted": "Cash, Credit Card, Mobile Money",
      "areaServed": "KE",
      "serviceType": "Online Marketplace"
    }
    
    # Render HTML with meta tags
    html_content = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          
          <!-- Primary Meta Tags -->
          <title>#{CGI.escapeHTML(title)}</title>
          <meta name="title" content="#{CGI.escapeHTML(title)}">
          <meta name="description" content="#{CGI.escapeHTML(description)}">
          <meta name="keywords" content="#{CGI.escapeHTML(keywords)}">
          <meta name="author" content="#{CGI.escapeHTML(@shop.enterprise_name)} Team">
          <meta name="robots" content="index, follow">
          <meta name="language" content="English">
          <meta name="geo.region" content="KE">
          <meta name="geo.placename" content="#{CGI.escapeHTML(location)}">
          <meta name="geo.position" content="-1.2921;36.8219">
          <meta name="ICBM" content="-1.2921, 36.8219">
          
          <!-- Open Graph / Facebook -->
          <meta property="og:type" content="website">
          <meta property="og:url" content="#{CGI.escapeHTML(shop_url)}">
          <meta property="og:title" content="#{CGI.escapeHTML(title)}">
          <meta property="og:description" content="#{CGI.escapeHTML(description)}">
          <meta property="og:image" content="#{CGI.escapeHTML(image_url)}">
          <meta property="og:image:width" content="1200">
          <meta property="og:image:height" content="630">
          <meta property="og:image:type" content="image/png">
          <meta property="og:site_name" content="Carbon Cube Kenya">
          <meta property="og:locale" content="en_US">
          <meta property="og:updated_time" content="#{@shop.updated_at || @shop.created_at}">
          
          <!-- Twitter Card -->
          <meta name="twitter:card" content="summary_large_image">
          <meta name="twitter:site" content="@carboncube_kenya">
          <meta name="twitter:creator" content="@carboncube_kenya">
          <meta name="twitter:title" content="#{CGI.escapeHTML(title)}">
          <meta name="twitter:description" content="#{CGI.escapeHTML(description)}">
          <meta name="twitter:image" content="#{CGI.escapeHTML(image_url)}">
          <meta name="twitter:image:alt" content="#{CGI.escapeHTML(@shop.enterprise_name)} - Shop on Carbon Cube Kenya">
          
          <!-- Business Specific Meta Tags -->
          <meta name="business:name" content="#{CGI.escapeHTML(@shop.enterprise_name)}">
          <meta name="business:type" content="Local Business">
          <meta name="business:location" content="#{CGI.escapeHTML(location)}">
          <meta name="business:rating" content="#{average_rating}">
          <meta name="business:review_count" content="#{total_reviews}">
          <meta name="business:product_count" content="#{product_count}">
          <meta name="business:tier" content="#{CGI.escapeHTML(tier)}">
          
          <!-- Additional Meta Tags -->
          <meta name="application-name" content="Carbon Cube Kenya">
          <meta name="apple-mobile-web-app-title" content="#{CGI.escapeHTML(@shop.enterprise_name)} - Carbon Cube">
          <meta name="msapplication-TileTitle" content="#{CGI.escapeHTML(@shop.enterprise_name)} Shop">
          <meta name="msapplication-TileColor" content="#FFD700">
          
          <!-- Canonical URL -->
          <link rel="canonical" href="#{CGI.escapeHTML(shop_url)}">
          
          <!-- Structured Data -->
          <script type="application/ld+json">
          #{structured_data.to_json}
          </script>
          
          <!-- Redirect to actual shop page -->
          <script>
              setTimeout(function() {
                  window.location.replace('#{CGI.escapeHTML(shop_url)}');
              }, 2000);
          </script>
          
          <!-- Fallback redirect for non-JS users -->
          <noscript>
              <meta http-equiv="refresh" content="0; url=#{CGI.escapeHTML(shop_url)}">
          </noscript>
          
          <style>
              body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
                  margin: 0;
                  padding: 20px;
                  background-color: #f5f5f5;
                  text-align: center;
              }
              .preview {
                  max-width: 600px;
                  margin: 50px auto;
                  padding: 40px;
                  background: white;
                  border-radius: 8px;
                  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
              }
              .shop-info {
                  text-align: left;
                  margin: 20px 0;
              }
              .shop-name {
                  color: #333;
                  font-size: 24px;
                  font-weight: bold;
                  margin-bottom: 10px;
              }
              .shop-description {
                  color: #666;
                  line-height: 1.6;
                  margin-bottom: 15px;
                  font-size: 16px;
              }
              .shop-stats {
                  display: flex;
                  gap: 20px;
                  margin: 20px 0;
                  flex-wrap: wrap;
              }
              .stat {
                  background: #f8f9fa;
                  padding: 10px 15px;
                  border-radius: 5px;
                  font-size: 14px;
                  color: #495057;
              }
              .redirect-notice {
                  background: #e8f4fd;
                  border: 1px solid #bee5eb;
                  border-radius: 4px;
                  padding: 15px;
                  margin-top: 20px;
                  color: #0c5460;
              }
              .spinner {
                  width: 40px;
                  height: 40px;
                  border: 4px solid #f3f3f3;
                  border-top: 4px solid #FFD700;
                  border-radius: 50%;
                  animation: spin 1s linear infinite;
                  margin: 0 auto 20px;
              }
              @keyframes spin {
                  0% { transform: rotate(0deg); }
                  100% { transform: rotate(360deg); }
              }
          </style>
      </head>
      <body>
          <div class="preview">
              <div class="spinner"></div>
              <div class="shop-info">
                  <div class="shop-name">#{CGI.escapeHTML(@shop.enterprise_name)}</div>
                  <div class="shop-description">#{CGI.escapeHTML(description)}</div>
                  <div class="shop-stats">
                      <div class="stat">#{product_count} Products</div>
                      <div class="stat">#{tier} Tier</div>
                      #{average_rating > 0 ? "<div class=\"stat\">#{average_rating}/5 Rating</div>" : ""}
                      #{total_reviews > 0 ? "<div class=\"stat\">#{total_reviews} Reviews</div>" : ""}
                  </div>
              </div>
              <div class="redirect-notice">
                  <strong>Redirecting...</strong> You will be automatically redirected to the shop page in a moment.
              </div>
          </div>
      </body>
      </html>
    HTML
    
    render html: html_content.html_safe
  end
end
