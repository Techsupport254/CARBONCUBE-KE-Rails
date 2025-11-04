class ShopsController < ApplicationController
  def show
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug)
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
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
                .order('tiers.id DESC, RANDOM()')
                .offset((page - 1) * per_page)
                .limit(per_page)
    
    # Get total count for pagination
    @total_count = @shop.ads.active.where(flagged: false).count
    
    # Calculate review statistics for SEO
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count

    # Calculate average rating correctly: average of each ad's rating, not all individual reviews
    if total_reviews > 0
      # Get all ads for this seller with their reviews
      seller_ads = @shop.ads.includes(:reviews)

      # Calculate average rating for each ad that has reviews, then average those
      ad_ratings = seller_ads.map do |ad|
        ad_reviews = all_reviews.where(ad_id: ad.id)
        ad_reviews.any? ? ad_reviews.average(:rating).to_f : nil
      end.compact # Remove nil values (ads with no reviews)

      # Only include rated ads in the calculation
      average_rating = ad_ratings.any? ? (ad_ratings.sum / ad_ratings.size).round(1) : 0.0
    else
      average_rating = 0.0
    end
    
    # Get shop categories for SEO
    shop_categories = @shop.categories.pluck(:name).join(', ')
    
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
        created_at: @shop.created_at,
        # SEO-specific fields
        fullname: @shop.fullname,
        phone_number: @shop.phone_number,
        city: @shop.city,
        county: @shop.county&.name,
        sub_county: @shop.sub_county&.name,
        business_registration_number: @shop.business_registration_number,
        categories: shop_categories,
        total_reviews: total_reviews,
        average_rating: average_rating,
        slug: slug
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
    
    @shop = find_shop_by_slug(slug)
    
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

    # Calculate average rating correctly: average of each ad's rating, not all individual reviews
    if total_reviews > 0
      # Get all ads for this seller with their reviews
      seller_ads = @shop.ads.includes(:reviews)

      # Calculate average rating for each ad that has reviews, then average those
      ad_ratings = seller_ads.map do |ad|
        ad_reviews = all_reviews.where(ad_id: ad.id)
        ad_reviews.any? ? ad_reviews.average(:rating).to_f : nil
      end.compact # Remove nil values (ads with no reviews)

      # Only include rated ads in the calculation
      average_rating = ad_ratings.any? ? (ad_ratings.sum / ad_ratings.size).round(1) : 0.0
    else
      average_rating = 0.0
    end

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
        comment: review.review, # Also include as 'comment' for frontend compatibility
        images: review.images || [],
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

  def meta_tags
    # Find shop by slug (enterprise_name converted to slug)
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug)
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    # Calculate review statistics
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count

    # Calculate average rating correctly: average of each ad's rating, not all individual reviews
    if total_reviews > 0
      # Get all ads for this seller with their reviews
      seller_ads = @shop.ads.includes(:reviews)

      # Calculate average rating for each ad that has reviews, then average those
      ad_ratings = seller_ads.map do |ad|
        ad_reviews = all_reviews.where(ad_id: ad.id)
        ad_reviews.any? ? ad_reviews.average(:rating).to_f : nil
      end.compact # Remove nil values (ads with no reviews)

      # Only include rated ads in the calculation
      average_rating = ad_ratings.any? ? (ad_ratings.sum / ad_ratings.size).round(1) : 0.0
    else
      average_rating = 0.0
    end

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
    
    meta_tags_data = {
      title: title,
      description: description,
      keywords: keywords,
      url: shop_url,
      image: image_url,
      image_width: 1200,
      image_height: 630,
      type: "website",
      site_name: "Carbon Cube Kenya",
      locale: "en_US",
      
      # Open Graph specific
      og_type: "website",
      og_url: shop_url,
      og_title: title,
      og_description: description,
      og_image: image_url,
      og_image_type: "image/png",
      og_image_width: 1200,
      og_image_height: 630,
      og_site_name: "Carbon Cube Kenya",
      og_locale: "en_US",
      
      # Twitter Card specific
      twitter_card: "summary_large_image",
      twitter_site: "@carboncube_kenya",
      twitter_creator: "@carboncube_kenya",
      twitter_title: title,
      twitter_description: description,
      twitter_image: image_url,
      
      # Business specific
      business_name: @shop.enterprise_name,
      business_type: "Local Business",
      business_location: location,
      business_rating: average_rating.to_s,
      business_review_count: total_reviews.to_s,
      business_product_count: product_count.to_s,
      business_tier: tier,
      
      # Additional meta
      canonical_url: shop_url,
      updated_time: @shop.updated_at || @shop.created_at,
      
      # Structured data
      structured_data: {
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
    }
    
    render json: meta_tags_data
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Shop not found' }, status: :not_found
  end

  # POST /shop/:slug/reviews
  def create_review
    # Find shop by slug
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug)
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end

    # Authenticate buyer
    begin
      buyer_auth = BuyerAuthorizeApiRequest.new(request.headers)
      @current_buyer = buyer_auth.result
    rescue => e
      @current_buyer = nil
    end

    unless @current_buyer&.is_a?(Buyer)
      render json: { error: 'Only buyers can create reviews' }, status: :forbidden
      return
    end

    # Determine which ad to review
    ad = nil
    if params[:review][:product_id].present?
      # Find the specific ad by product_id (which is actually ad_id)
      ad = @shop.ads.active.find_by(id: params[:review][:product_id])
      unless ad
        render json: { error: 'Product not found' }, status: :not_found
        return
      end
    else
      # If no product_id provided, use the shop's first active ad
      # This allows general shop reviews
      ad = @shop.ads.active.where(flagged: false).first
      unless ad
        render json: { error: 'No products available for review. Please select a specific product.' }, status: :unprocessable_entity
        return
      end
    end

    # Process and upload images if present
    if params[:review][:images].present? && params[:review][:images].is_a?(Array)
      begin
        uploaded_images = process_and_upload_review_images(params[:review][:images])
        params[:review][:images] = uploaded_images
      rescue => e
        Rails.logger.error "Error processing review images: #{e.message}"
        return render json: { error: "Failed to process images. Please try again." }, status: :unprocessable_entity
      end
    else
      params[:review][:images] = []
    end

    # Create the review
    review_attrs = review_params
    # Map 'comment' to 'review' if comment is provided (for shop reviews)
    review_attrs[:review] = review_attrs[:comment] if review_attrs[:comment].present? && review_attrs[:review].blank?
    review_attrs.delete(:comment) # Remove comment as it's not a model field
    
    @review = ad.reviews.new(review_attrs)
    @review.buyer = @current_buyer

    if @review.save
      render json: @review.as_json(include: :buyer), status: :created
    else
      render json: @review.errors, status: :unprocessable_entity
    end
  end

  private

  # Helper method to find shop by slug, handling special characters like apostrophes and newlines
  def find_shop_by_slug(slug)
    # Convert slug back to enterprise name format for searching
    # Replace hyphens and underscores with spaces
    enterprise_name_from_slug = slug.gsub('-', ' ').gsub('_', ' ')
    
    # Normalize the slug-derived name (remove special characters, normalize spaces)
    # This matches how slugs are generated: special chars removed, spaces normalized
    normalized_slug_name = normalize_shop_name(enterprise_name_from_slug)
    
    # Try multiple lookup strategies
    
    # Strategy 1: Exact match with normalized spaces (handles multi-spaces, newlines, etc.)
    normalized_enterprise_name = enterprise_name_from_slug.downcase.strip.squeeze(' ')
    shop = Seller.includes(:seller_tier, :tier)
                 .where(deleted: false)
                 .where('LOWER(TRIM(REGEXP_REPLACE(enterprise_name, \'\\s+\', \' \', \'g\'))) = ?', normalized_enterprise_name)
                 .first
    
    # Strategy 2: Match by normalized name (removes special chars like apostrophes, newlines)
    # This handles cases like "Rick's" -> "ricks" in the slug
    unless shop
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where('LOWER(REGEXP_REPLACE(REGEXP_REPLACE(enterprise_name, \'[^a-z0-9\\s]\', \'\', \'g\'), \'\\s+\', \' \', \'g\')) = ?', normalized_slug_name)
                   .first
    end
    
    # Strategy 3: Partial match with normalized spaces
    unless shop
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where('LOWER(TRIM(REGEXP_REPLACE(enterprise_name, \'\\s+\', \' \', \'g\'))) ILIKE ?', "%#{normalized_enterprise_name}%")
                   .first
    end
    
    # Strategy 4: Partial match with normalized name (removes special chars)
    unless shop
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where('LOWER(REGEXP_REPLACE(REGEXP_REPLACE(enterprise_name, \'[^a-z0-9\\s]\', \'\', \'g\'), \'\\s+\', \' \', \'g\')) ILIKE ?', "%#{normalized_slug_name}%")
                   .first
    end
    
    # Strategy 5: Try to find by ID as fallback (for backward compatibility)
    unless shop
      begin
        shop_id = slug.to_i
        if shop_id > 0
          shop = Seller.includes(:seller_tier, :tier)
                       .where(deleted: false)
                       .find(shop_id)
        end
      rescue ActiveRecord::RecordNotFound
        # Ignore and continue to return nil
      end
    end
    
    shop
  end
  
  # Normalize shop name by removing special characters and normalizing spaces
  # This matches the slug generation logic: remove special chars, normalize spaces
  def normalize_shop_name(name)
    return '' if name.blank?
    
    # Convert to lowercase, remove special characters (keep only alphanumeric and spaces)
    # Then normalize spaces (replace multiple spaces/newlines with single space, trim)
    normalized = name.to_s.downcase
                    .gsub(/[^a-z0-9\s]/, '')  # Remove special characters (apostrophes, etc.)
                    .gsub(/\s+/, ' ')         # Replace multiple spaces/newlines with single space
                    .strip                     # Trim whitespace
    normalized
  end

  def review_params
    params.require(:review).permit(:rating, :review, :comment, images: [])
  end

  # Upload review images to Cloudinary (same method as Buyer::ReviewsController)
  def process_and_upload_review_images(images)
    uploaded_urls = []
    Rails.logger.info "🖼️ Processing #{Array(images).length} review images for upload"

    begin
      Array(images).each do |image|
        begin
          # Skip if it's already a URL (shouldn't happen, but safety check)
          if image.is_a?(String)
            uploaded_urls << image
            next
          end

          Rails.logger.info "📤 Processing review image: #{image.original_filename} (#{image.size} bytes)"
          
          unless image.tempfile && File.exist?(image.tempfile.path)
            Rails.logger.error "❌ Tempfile not found for image: #{image.original_filename}"
            next
          end
          
          unless ENV['UPLOAD_PRESET'].present?
            Rails.logger.error "❌ UPLOAD_PRESET environment variable is not set"
            raise "UPLOAD_PRESET not configured"
          end
          
          # Upload to Cloudinary
          Rails.logger.info "🚀 Uploading review image to Cloudinary"
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET'],
            folder: "review_images"
          )
          Rails.logger.info "✅ Uploaded review image: #{uploaded_image['secure_url']}"

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          Rails.logger.error "❌ Error uploading review image #{image.original_filename}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    rescue => e
      Rails.logger.error "❌ Error in process_and_upload_review_images: #{e.message}"
      raise e
    end

    Rails.logger.info "✅ Successfully uploaded #{uploaded_urls.length} review images"
    uploaded_urls
  end

end
