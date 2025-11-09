class OfferSerializer
  def initialize(offer)
    @offer = offer
  end
  
  def as_json
    {
      id: @offer.id,
      name: @offer.name,
      description: @offer.description,
      offer_type: @offer.offer_type,
      status: @offer.status,
      banner_color: @offer.banner_color,
      badge_color: @offer.badge_color,
      icon_name: @offer.icon_name,
      banner_image_url: @offer.banner_image_url,
      hero_image_url: @offer.hero_image_url,
      start_time: @offer.start_time,
      end_time: @offer.end_time,
      is_recurring: @offer.is_recurring,
      recurrence_pattern: @offer.recurrence_pattern,
      discount_percentage: @offer.discount_percentage,
      fixed_discount_amount: @offer.fixed_discount_amount,
      discount_type: @offer.discount_type,
      target_categories: @offer.target_categories,
      target_sellers: @offer.target_sellers,
      target_products: @offer.target_products,
      eligibility_criteria: @offer.eligibility_criteria,
      minimum_order_amount: @offer.minimum_order_amount,
      max_uses_per_customer: @offer.max_uses_per_customer,
      total_usage_limit: @offer.total_usage_limit,
      priority: @offer.priority,
      featured: @offer.featured,
      show_on_homepage: @offer.show_on_homepage,
      show_badge: @offer.show_badge,
      badge_text: @offer.badge_text,
      cta_text: @offer.cta_text,
      terms_and_conditions: @offer.terms_and_conditions,
      view_count: @offer.view_count,
      click_count: @offer.click_count,
      conversion_count: @offer.conversion_count,
      revenue_generated: @offer.revenue_generated,
      conversion_rate: @offer.conversion_rate,
      click_through_rate: @offer.click_through_rate,
      created_at: @offer.created_at,
      updated_at: @offer.updated_at,
      # Computed attributes
      active: @offer.active?,
      upcoming: @offer.upcoming?,
      expired: @offer.expired?,
      time_remaining: @offer.time_remaining,
      time_until_start: @offer.time_until_start,
      duration_in_hours: @offer.duration_in_hours,
      progress_percentage: @offer.progress_percentage,
      can_be_activated: @offer.can_be_activated?,
              # Seller info
              seller: {
                id: @offer.seller&.id,
                enterprise_name: @offer.seller&.enterprise_name,
                fullname: @offer.seller&.fullname
              },
              # Ads with discounts - exclude ads from flagged, blocked, or deleted sellers
              ads: @offer.offer_ads.active
                .joins(ad: :seller)
                .where(sellers: { blocked: false, deleted: false, flagged: false })
                .map do |offer_ad|
                ad = offer_ad.ad
                seller = ad.seller
                seller_tier = seller&.seller_tier
                tier_id = seller_tier&.tier_id || 1
                
                # Get tier name
                tier_name = case tier_id
                when 4 then "Premium"
                when 3 then "Standard"
                when 2 then "Basic"
                when 1 then "Free"
                else "Free"
                end
                
                # Get tier priority
                tier_priority = case tier_id
                when 4 then 1  # Premium
                when 3 then 2  # Standard
                when 2 then 3  # Basic
                when 1 then 4  # Free
                else 4
                end
                
                {
                  id: ad.id,
                  title: ad.title,
                  original_price: offer_ad.original_price,
                  discounted_price: offer_ad.discounted_price,
                  discount_percentage: offer_ad.discount_percentage,
                  savings_amount: offer_ad.savings_amount,
                  first_media_url: ad.first_media_url,
                  category_name: ad.category&.name,
                  subcategory_name: ad.subcategory&.name,
                  seller_notes: offer_ad.seller_notes,
                  # Seller tier information
                  seller_tier: tier_id,
                  seller_tier_name: tier_name,
                  tier_priority: tier_priority,
                  seller_name: seller&.fullname || seller&.enterprise_name,
                  # Additional useful fields
                  media_urls: ad.valid_media_urls,
                  rating: ad.reviews.average(:rating)&.round(1) || 0.0,
                  review_count: ad.reviews.count
                }
              end
    }
  end
  
  # Custom serialization for different contexts
  def self.serialize_for_homepage(offers)
    offers.map do |offer|
      {
        id: offer.id,
        name: offer.name,
        description: offer.description,
        offer_type: offer.offer_type,
        banner_color: offer.banner_color,
        badge_color: offer.badge_color,
        icon_name: offer.icon_name,
        badge_text: offer.badge_text,
        cta_text: offer.cta_text,
        discount_percentage: offer.discount_percentage,
        discount_type: offer.discount_type,
        start_time: offer.start_time,
        end_time: offer.end_time,
        time_remaining: offer.time_remaining,
        progress_percentage: offer.progress_percentage,
        featured: offer.featured,
        priority: offer.priority
      }
    end
  end
  
  def self.serialize_for_admin(offers)
    offers.map do |offer|
      {
        id: offer.id,
        name: offer.name,
        description: offer.description,
        offer_type: offer.offer_type,
        status: offer.status,
        banner_color: offer.banner_color,
        badge_color: offer.badge_color,
        icon_name: offer.icon_name,
        badge_text: offer.badge_text,
        start_time: offer.start_time,
        end_time: offer.end_time,
        discount_percentage: offer.discount_percentage,
        discount_type: offer.discount_type,
        featured: offer.featured,
        priority: offer.priority,
        view_count: offer.view_count,
        click_count: offer.click_count,
        conversion_count: offer.conversion_count,
        revenue_generated: offer.revenue_generated,
        conversion_rate: offer.conversion_rate,
        click_through_rate: offer.click_through_rate,
        seller_name: offer.seller&.enterprise_name || offer.seller&.fullname,
        created_at: offer.created_at,
        updated_at: offer.updated_at
      }
    end
  end
  
  def self.serialize_for_calendar(offers)
    offers.map do |offer|
      {
        id: offer.id,
        title: offer.name,
        start: offer.start_time,
        end: offer.end_time,
        type: offer.offer_type,
        status: offer.status,
        color: offer.banner_color,
        featured: offer.featured,
        description: offer.description,
        badge_text: offer.badge_text,
        discount_percentage: offer.discount_percentage
      }
    end
  end
  
  def self.serialize_for_analytics(offers)
    {
      total_offers: offers.count,
      active_offers: offers.select(&:active?).count,
      total_views: offers.sum(&:view_count),
      total_clicks: offers.sum(&:click_count),
      total_conversions: offers.sum(&:conversion_count),
      total_revenue: offers.sum(&:revenue_generated),
      average_conversion_rate: offers.map(&:conversion_rate).compact.sum / offers.count,
      top_performing_offers: offers.sort_by(&:revenue_generated).reverse.first(5).map do |offer|
        {
          id: offer.id,
          name: offer.name,
          revenue: offer.revenue_generated,
          conversions: offer.conversion_count,
          conversion_rate: offer.conversion_rate
        }
      end,
      offers_by_type: offers.group_by(&:offer_type).transform_values(&:count),
      offers_by_status: offers.group_by(&:status).transform_values(&:count)
    }
  end
end
