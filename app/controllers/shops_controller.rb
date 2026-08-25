class ShopsController < ApplicationController
  def locations
    locations = Seller.joins(:ads, :county)
                     .where(ads: { flagged: false, deleted: false })
                     .where(deleted: false, blocked: false, flagged: false)
                     .where.not(county_id: nil)
                     .includes(:county, :sub_county)
                     .pluck(:city, "counties.name", "sub_counties.name", :county_id)
                     .uniq
                     .map do |city, county_name, sub_county_name, county_id|
                       location_name = city || county_name || sub_county_name || "Kenya"
                       {
                         id: county_id,
                         name: location_name,
                         slug: location_name&.parameterize,
                         county_name: county_name,
                         sub_county_name: sub_county_name,
                         full_name: [city, sub_county_name, county_name].compact.uniq.join(", ")
                       }
                     end
                     .uniq { |loc| loc[:slug] }
                     .sort_by { |loc| loc[:name] }

    render json: locations
  end

  def show
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug)
    
    unless @shop
      if params[:id].present?
        begin
          if params[:id].to_s.include?('-')
            @shop = Seller.includes(:seller_tier, :tier)
                         .where(deleted: false)
                         .find_by(id: params[:id])
          else
            shop_id = params[:id].to_i
            if shop_id > 0
              @shop = Seller.includes(:seller_tier, :tier)
                           .where(deleted: false)
                           .find_by(id: shop_id)
            end
          end
        rescue ActiveRecord::RecordNotFound
        end
      end
    end
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 24
    
    @shop = Seller.includes(
      :categories,
      :county,
      :sub_county,
      :seller_documents,
      seller_tier: :tier
    ).find(@shop.id)
    
    @ads = @shop.ads
                .active
                .where(flagged: false)
                .joins(:category, :subcategory, seller: { seller_tier: :tier })
                .left_joins(:reviews)
                .includes(
                  :category,
                  :subcategory,
                  :reviews,
                  :offer_ads,
                  seller: { 
                    seller_tier: :tier,
                    categories: []
                  },
                  offer_ads: :offer
                )
                .order('tiers.id DESC, ads.created_at DESC')
                .offset((page - 1) * per_page)
                .limit(per_page)
                
    @ads.load
    
    @total_count = @shop.ads.active.where(flagged: false).count
    
    total_reviews = Review.joins(:ad)
                         .where(ads: { seller_id: @shop.id })
                         .count
    
    average_rating = Review.joins(:ad)
                           .where(ads: { seller_id: @shop.id })
                           .average(:rating)
                           .to_f
                           .round(1)
    
    shop_categories = @shop.categories.map(&:name).join(', ')
    
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
        fullname: @shop.fullname,
        phone_number: @shop.phone_number,
        secondary_phone_number: @shop.secondary_phone_number,
        city: @shop.city || @shop.sub_county&.name || @shop.county&.name,
        county: @shop.county&.name,
        sub_county: @shop.sub_county&.name,
        business_registration_number: @shop.business_registration_number,
        categories: shop_categories,
        total_reviews: total_reviews,
        average_rating: average_rating,
        slug: slug,
        document_verified: @shop.document_verified,
        seller_documents: @shop.seller_documents.map do |doc|
          {
            id: doc.id,
            document_type_id: doc.document_type_id,
            document_url: doc.document_url,
            document_expiry_date: doc.document_expiry_date,
            document_verified: doc.document_verified,
            document_type: doc.document_type ? {
              id: doc.document_type.id,
              name: doc.document_type.name
            } : nil
          }
        end
      },
      ads: @ads.map { |ad| AdSerializer.new(ad, include_reviews: false).as_json },
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
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug) || (params[:id].present? ? Seller.includes(:seller_tier, :tier).find_by(id: params[:id], deleted: false) : nil)
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    page = [params[:page].to_i, 1].max
    per_page = [[params[:per_page].to_i, 1].max, 100].min
    
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count
    average_rating = all_reviews.average(:rating).to_f.round(1)

    google_reviews = @shop.respond_to?(:google_place_reviews) ? (@shop.google_place_reviews || []) : []
    google_reviews_count = google_reviews.size
    google_average_rating = if google_reviews_count > 0
      (google_reviews.sum { |r| r["rating"].to_f } / google_reviews_count).round(1)
    else
      0.0
    end

    @reviews = all_reviews
                 .includes(:buyer, :ad)
                 .order(created_at: :desc)
                 .offset((page - 1) * per_page)
                 .limit(per_page)
    sellers_by_id = Seller.where(id: @reviews.filter_map(&:seller_id)).index_by { |seller| seller.id.to_s }

    rating_distribution = (1..5).map do |rating|
      count = all_reviews.where(rating: rating).count
      percentage = total_reviews > 0 ? (count.to_f / total_reviews * 100).round(1) : 0
      { rating: rating, count: count, percentage: percentage }
    end
    
    reviews_data = @reviews.map do |review|
      seller = sellers_by_id[review.seller_id.to_s]

      {
        id: review.id,
        rating: review.rating,
        review: review.review,
        comment: review.review,
        images: review.images || [],
        seller_reply: review.seller_reply,
        created_at: review.created_at,
        updated_at: review.updated_at,
        buyer: review.buyer && {
          id: review.buyer.id,
          name: review.buyer.fullname || review.buyer.name || "Buyer ##{review.buyer.id}",
          username: review.buyer.username,
          profile_picture: review.buyer.profile_picture
        },
        seller: seller && {
          id: seller.id,
          name: seller.fullname,
          enterprise_name: seller.enterprise_name,
          profile_picture: seller.profile_picture
        },
        ad: {
          id: review.ad.id,
          title: review.ad.title,
          price: review.ad.price,
          first_media_url: review.ad.first_valid_media_url,
          media_urls: review.ad.valid_media_urls
        }
      }
    end
    
    render json: {
      reviews: reviews_data,
      google_reviews: google_reviews,
      statistics: {
        total_reviews: total_reviews,
        average_rating: average_rating,
        google_reviews_count: google_reviews_count,
        google_average_rating: google_average_rating,
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
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug) || (params[:id].present? ? Seller.includes(:seller_tier, :tier).find_by(id: params[:id], deleted: false) : nil)
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end
    
    all_reviews = Review.joins(:ad).where(ads: { seller_id: @shop.id })
    total_reviews = all_reviews.count

    average_rating = all_reviews.average(:rating).to_f.round(1)

    shop_categories = @shop.categories.pluck(:name).join(', ')
    
    location = [@shop.city, @shop.sub_county&.name, @shop.county&.name].compact.join(', ')
    tier = @shop.seller_tier&.tier&.name || 'Free'
    product_count = @shop.ads.active.where(flagged: false).count
    
    title = "#{@shop.enterprise_name} - Shop | #{product_count} Products | #{tier} Tier Seller"
    
    rating_text = average_rating > 0 ? " Rated #{average_rating}/5 stars" : ""
    reviews_text = total_reviews > 0 ? " with #{total_reviews} reviews" : ""
    location_text = location.present? ? " in #{location}" : ""
    
    description = if @shop.description.present?
      "#{@shop.description[0..160]}... Shop #{@shop.enterprise_name} on Carbon Cube Kenya. #{product_count} products available from #{tier} tier verified seller#{location_text}.#{rating_text}#{reviews_text}. Fast delivery across Kenya."
    else
      "Shop #{@shop.enterprise_name} on Carbon Cube Kenya. #{product_count} products available from #{tier} tier verified seller#{location_text}.#{rating_text}#{reviews_text}. Browse quality products with fast delivery across Kenya."
    end
    
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
      
      twitter_card: "summary_large_image",
      twitter_site: "@carboncube_kenya",
      twitter_creator: "@carboncube_kenya",
      twitter_title: title,
      twitter_description: description,
      twitter_image: image_url,
      
      business_name: @shop.enterprise_name,
      business_type: "Local Business",
      business_location: location,
      business_rating: average_rating.to_s,
      business_review_count: total_reviews.to_s,
      business_product_count: product_count.to_s,
      business_tier: tier,
      
      canonical_url: shop_url,
      updated_time: @shop.updated_at || @shop.created_at,
      
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

  def create_review
    slug = params[:slug]
    
    @shop = find_shop_by_slug(slug) || (params[:id].present? ? Seller.includes(:seller_tier, :tier).find_by(id: params[:id], deleted: false) : nil)
    
    unless @shop
      render json: { error: 'Shop not found' }, status: :not_found
      return
    end

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

    ad = nil
    if params[:review][:product_id].present?
      ad = @shop.ads.active.find_by(id: params[:review][:product_id])
      unless ad
        render json: { error: 'Product not found' }, status: :not_found
        return
      end
    else
      ad = @shop.ads.active.where(flagged: false).first
      unless ad
        render json: { error: 'No products available for review. Please select a specific product.' }, status: :unprocessable_entity
        return
      end
    end

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

    review_attrs = review_params
    review_attrs[:review] = review_attrs[:comment] if review_attrs[:comment].present? && review_attrs[:review].blank?
    review_attrs.delete(:comment)
    
    @review = ad.reviews.new(review_attrs)
    @review.buyer = @current_buyer

    if @review.save
      render json: @review.as_json(include: :buyer), status: :created
    else
      render json: @review.errors, status: :unprocessable_entity
    end
  end

  private

  def find_shop_by_slug(slug)
    return nil if slug.blank?

    slug_str = slug.to_s.strip
    enterprise_name_from_slug = slug_str.gsub(/[-_]/, ' ')
    normalized_slug = normalize_shop_name(enterprise_name_from_slug)
    slug_without_and = normalized_slug.gsub(/\band\b/, ' ').gsub(/\s+/, ' ').strip

    # 1. Exact match on username
    shop = Seller.includes(:seller_tier, :tier)
                 .where(deleted: false)
                 .where('LOWER(TRIM(username)) = ?', slug_str.downcase)
                 .first
    return shop if shop

    # 2. Direct exact match on enterprise_name or fullname
    shop = Seller.includes(:seller_tier, :tier)
                 .where(deleted: false)
                 .where('LOWER(TRIM(enterprise_name)) = ? OR LOWER(TRIM(fullname)) = ?', enterprise_name_from_slug.downcase, enterprise_name_from_slug.downcase)
                 .first
    return shop if shop

    # 3. Clean alphanumeric exact match on enterprise_name or fullname (Handles &, Ltd., special chars)
    sql_clean_enterprise = "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(LOWER(enterprise_name), '[^a-z0-9]', ' ', 'g'), '\\s+', ' ', 'g'))"
    sql_clean_fullname = "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(LOWER(fullname), '[^a-z0-9]', ' ', 'g'), '\\s+', ' ', 'g'))"
    
    shop = Seller.includes(:seller_tier, :tier)
                 .where(deleted: false)
                 .where("#{sql_clean_enterprise} = ? OR #{sql_clean_fullname} = ?", normalized_slug, normalized_slug)
                 .first
    return shop if shop

    # 4. Try matching without 'and' / '&' (e.g. 'morgan steel works hardware ltd' vs 'morgan steel works & hardware ltd')
    if slug_without_and.present? && slug_without_and != normalized_slug
      sql_clean_no_and_ent = "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(#{sql_clean_enterprise}, '\\band\\b', ' ', 'g'), '\\s+', ' ', 'g'))"
      sql_clean_no_and_fn = "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(#{sql_clean_fullname}, '\\band\\b', ' ', 'g'), '\\s+', ' ', 'g'))"
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where("#{sql_clean_no_and_ent} = ? OR #{sql_clean_no_and_fn} = ?", slug_without_and, slug_without_and)
                   .first
      return shop if shop
    end

    # Also handle if the DB has 'and'/'&' but the slug did not have 'and'
    if normalized_slug.present?
      sql_clean_no_and_ent = "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(#{sql_clean_enterprise}, '\\band\\b', ' ', 'g'), '\\s+', ' ', 'g'))"
      sql_clean_no_and_fn = "TRIM(REGEXP_REPLACE(REGEXP_REPLACE(#{sql_clean_fullname}, '\\band\\b', ' ', 'g'), '\\s+', ' ', 'g'))"
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where("#{sql_clean_no_and_ent} = ? OR #{sql_clean_no_and_fn} = ?", normalized_slug, normalized_slug)
                   .first
      return shop if shop
    end

    # 5. Handle 'limited' vs 'ltd'
    slug_ltd = normalized_slug.gsub(/\blimited\b/, 'ltd').gsub(/\s+/, ' ').strip
    slug_limited = normalized_slug.gsub(/\bltd\b/, 'limited').gsub(/\s+/, ' ').strip
    [slug_ltd, slug_limited].uniq.each do |variant|
      next if variant.blank? || variant == normalized_slug
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where("#{sql_clean_enterprise} = ? OR #{sql_clean_fullname} = ?", variant, variant)
                   .first
      return shop if shop
    end

    # 6. ILIKE contains match for normalized alphanumeric text
    if normalized_slug.length >= 4
      shop = Seller.includes(:seller_tier, :tier)
                   .where(deleted: false)
                   .where("#{sql_clean_enterprise} ILIKE ? OR #{sql_clean_fullname} ILIKE ?", "%#{normalized_slug}%", "%#{normalized_slug}%")
                   .first
      return shop if shop
    end

    # 7. Numeric ID lookup
    if slug_str =~ /\A\d+\z/
      begin
        shop = Seller.includes(:seller_tier, :tier).where(deleted: false).find_by(id: slug_str.to_i)
        return shop if shop
      rescue ActiveRecord::RecordNotFound
      end
    end

    # 8. Ruby in-memory parameterize fallback for edge cases
    first_word = enterprise_name_from_slug.split.first
    if first_word.present? && first_word.length >= 3
      candidates = Seller.includes(:seller_tier, :tier)
                          .where(deleted: false)
                          .where('enterprise_name ILIKE ? OR fullname ILIKE ?', "%#{first_word}%", "%#{first_word}%")
                          .limit(50)
      shop = candidates.find do |candidate|
        ent_param = candidate.enterprise_name&.parameterize
        fn_param = candidate.fullname&.parameterize
        ent_slug = candidate.enterprise_name.present? ? normalize_shop_name(candidate.enterprise_name).gsub(/\s+/, '-') : nil
        fn_slug = candidate.fullname.present? ? normalize_shop_name(candidate.fullname).gsub(/\s+/, '-') : nil

        slug_str == ent_param || slug_str == fn_param || slug_str == ent_slug || slug_str == fn_slug
      end
      return shop if shop
    end

    nil
  end
  
  def normalize_shop_name(name)
    return '' if name.blank?
    
    name.to_s.downcase
        .gsub(/[^a-z0-9\s]/, '')
        .gsub(/\s+/, ' ')
        .strip
  end

  def review_params
    params.require(:review).permit(:rating, :review, :comment, images: [])
  end

  def process_and_upload_review_images(images)
    uploaded_urls = []

    begin
      Array(images).each do |image|
        begin
          if image.is_a?(String)
            uploaded_urls << image
            next
          end

          unless image.tempfile && File.exist?(image.tempfile.path)
            Rails.logger.error "Tempfile not found for image: #{image.original_filename}"
            next
          end
          
          unless ENV['UPLOAD_PRESET'].present?
            Rails.logger.error "UPLOAD_PRESET environment variable is not set"
            raise "UPLOAD_PRESET not configured"
          end
          
          uploaded_image = Cloudinary::Uploader.upload(
            image.tempfile.path,
            upload_preset: ENV['UPLOAD_PRESET'],
            folder: "review_images"
          )

          uploaded_urls << uploaded_image["secure_url"]
        rescue => e
          Rails.logger.error "Error uploading review image #{image.original_filename}: #{e.message}"
        end
      end
    rescue => e
      Rails.logger.error "Error in process_and_upload_review_images: #{e.message}"
      raise e
    end

    uploaded_urls
  end

end
