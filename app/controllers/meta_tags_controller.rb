class MetaTagsController < ApplicationController
  def shop
    begin
      slug = params[:slug]
      
      # Convert slug back to enterprise name format for searching (same logic as ShopsController)
      enterprise_name = slug.gsub('-', ' ').gsub('_', ' ')
      
      # Find shop by enterprise name (case insensitive)
      shop = Seller.includes(:seller_tier, :tier)
                   .where('LOWER(enterprise_name) = ?', enterprise_name.downcase)
                   .first
      
      # If no exact match, try partial match
      unless shop
        shop = Seller.includes(:seller_tier, :tier)
                     .where('LOWER(enterprise_name) ILIKE ?', "%#{enterprise_name.downcase}%")
                     .first
      end
      
      # If still no match, try to find by ID as fallback
      unless shop
        begin
          shop_id = slug.to_i
          if shop_id > 0
            shop = Seller.includes(:seller_tier, :tier).find(shop_id)
          end
        rescue ActiveRecord::RecordNotFound
          # Ignore and continue to error handling
        end
      end
    rescue => e
      Rails.logger.error "Error in MetaTagsController#shop: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      shop = nil
    end
    
    if shop
      # Generate shop-specific meta tags
      title = "#{shop.enterprise_name} | Carbon Cube Kenya"
      description = shop.description.presence || "#{shop.enterprise_name} - #{shop.tier&.name} seller offering #{shop.ads.active.count} quality products for online shopping on Carbon Cube Kenya"
      
      # Use shop profile picture or fallback
      image_url = if shop.profile_picture.present?
        if shop.profile_picture.start_with?('http')
          shop.profile_picture
        else
          "https://carboncube-ke.com#{shop.profile_picture}"
        end
      else
        "https://via.placeholder.com/1200x630/FFD700/000000?text=#{CGI.escape(shop.enterprise_name)}"
      end
      
      url = "https://carboncube-ke.com/shop/#{slug}"
      
      # Return HTML with meta tags for social media crawlers
      html_content = generate_meta_html(title, description, image_url, url, "website")
      render html: html_content.html_safe
    else
      # Fallback to default meta tags
      html_content = generate_meta_html(
        "Carbon Cube Kenya | Kenya's Trusted Digital Marketplace",
        "Carbon Cube Kenya is a smart, AI-powered marketplace built to connect credible sellers with serious buyers.",
        "https://carboncube-ke.com/logo.png",
        "https://carboncube-ke.com/",
        "website"
      )
      render html: html_content.html_safe
    end
  end
  
  def ad
    begin
      ad_id = params[:ad_id]
      
      # Find ad by ID
      ad = Ad.find_by(id: ad_id, deleted: false)
    rescue => e
      Rails.logger.error "Error in MetaTagsController#ad: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      ad = nil
    end
    
    if ad
      # Generate ad-specific meta tags
      title = "#{ad.title} | Carbon Cube Kenya"
      description = ad.description.presence || "#{ad.title} - #{ad.condition.humanize} #{ad.category_name} available for purchase on Carbon Cube Kenya"
      
      # Use first media URL or fallback
      image_url = if ad.media_urls.present? && ad.media_urls.first.present?
        ad.media_urls.first
      else
        "https://via.placeholder.com/1200x630/FFD700/000000?text=#{CGI.escape(ad.title)}"
      end
      
      url = "https://carboncube-ke.com/ads/#{ad_id}"
      
      # Return HTML with meta tags for social media crawlers
      html_content = generate_meta_html(title, description, image_url, url, "product")
      render html: html_content.html_safe
    else
      # Fallback to default meta tags
      html_content = generate_meta_html(
        "Carbon Cube Kenya | Kenya's Trusted Digital Marketplace",
        "Carbon Cube Kenya is a smart, AI-powered marketplace built to connect credible sellers with serious buyers.",
        "https://carboncube-ke.com/logo.png",
        "https://carboncube-ke.com/",
        "website"
      )
      render html: html_content.html_safe
    end
  end
  
  private
  
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
