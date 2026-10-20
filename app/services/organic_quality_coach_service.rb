class OrganicQualityCoachService
  def self.analyze(ad)
    new(ad).analyze
  end

  def initialize(ad)
    @ad = ad
    @seller = ad.seller
    @stats = AdStat.find_by(ad_id: ad.id)
  end

  def analyze
    images_info = evaluate_images
    desc_info = evaluate_description
    specs_info = evaluate_specifications
    pricing_info = evaluate_pricing
    trust_info = evaluate_trust
    engagement_info = evaluate_engagement
    freshness_info = evaluate_freshness

    total_score = [
      images_info[:points] +
      desc_info[:points] +
      specs_info[:points] +
      pricing_info[:points] +
      trust_info[:points] +
      engagement_info[:points] +
      freshness_info[:points],
      100.0
    ].min.round(1)

    is_active_featured = @ad.featured?
    in_cooldown = @ad.in_featured_cooldown?
    is_eligible = total_score >= OrganicFeaturedService::MIN_QUALITY_SCORE && !@ad.flagged && !@ad.deleted

    status = if is_active_featured
               :active_featured
             elsif in_cooldown
               :in_cooldown
             elsif is_eligible
               :eligible
             else
               :needs_improvement
             end

    recommendations = build_recommendations(
      images_info, desc_info, specs_info, pricing_info, trust_info
    )

    {
      ad_id: @ad.id,
      title: @ad.title,
      overall_score: total_score,
      min_qualifying_score: OrganicFeaturedService::MIN_QUALITY_SCORE,
      status: status,
      is_featured: is_active_featured,
      featured_until: @ad.featured_until,
      last_featured_at: @ad.last_featured_at,
      cooldown_until: @ad.last_featured_at ? @ad.last_featured_at + OrganicFeaturedService::COOLDOWN_PERIOD : nil,
      breakdown: {
        images: images_info,
        description: desc_info,
        specifications: specs_info,
        pricing: pricing_info,
        trust: trust_info,
        engagement: engagement_info,
        freshness: freshness_info
      },
      recommendations: recommendations
    }
  end

  private

  def evaluate_images
    media_count = media_items.size
    points = if media_count >= 3
               15.0
             elsif media_count >= 1
               10.0
             else
               0.0
             end

    {
      points: points,
      max_points: 15.0,
      count: media_count,
      status: points >= 15.0 ? 'Excellent' : (points >= 10.0 ? 'Good' : 'Needs Images'),
      tip: points >= 15.0 ? 'Great job! 3+ clear photos added.' : 'Add at least 3 high-resolution photos showing different angles to earn full +15 points.'
    }
  end

  def media_items
    items = @ad.media
    if items.is_a?(String)
      items = JSON.parse(items) rescue []
    end
    Array(items).reject(&:blank?)
  end

  def evaluate_description
    desc_length = @ad.description.to_s.strip.length
    points = if desc_length >= 250
               10.0
             elsif desc_length >= 100
               6.0
             elsif desc_length > 0
               2.0
             else
               0.0
             end

    {
      points: points,
      max_points: 10.0,
      char_count: desc_length,
      status: points >= 10.0 ? 'Complete' : (points >= 6.0 ? 'Moderate' : 'Too Short'),
      tip: points >= 10.0 ? 'Comprehensive description.' : 'Expand description to 250+ characters covering condition, features, and key specifications.'
    }
  end

  def evaluate_specifications
    has_brand = @ad.brand.present? && !['Generic', 'Other', ''].include?(@ad.brand)
    has_specs = @ad.specifications.present? && @ad.specifications != {} && @ad.specifications != 'null'

    points = 0.0
    points += 3.0 if has_brand
    points += 2.0 if has_specs

    {
      points: points,
      max_points: 5.0,
      has_brand: has_brand,
      has_specs: has_specs,
      status: points >= 5.0 ? 'Complete' : (points > 0 ? 'Partial' : 'Missing'),
      tip: points >= 5.0 ? 'Structured brand and specifications provided.' : 'Specify the manufacturer brand and add at least 2 technical specifications.'
    }
  end

  def evaluate_pricing
    has_price = @ad.price.to_f > 0
    pricing_unit = @ad.specifications.is_a?(Hash) ? @ad.specifications['pricing_unit'] : nil
    has_unit = pricing_unit.present?

    points = if has_price && has_unit
               5.0
             elsif has_price
               3.0
             else
               1.0
             end

    {
      points: points,
      max_points: 5.0,
      price: @ad.price.to_f,
      pricing_unit: pricing_unit,
      status: points >= 5.0 ? 'Transparent' : (points >= 3.0 ? 'Good' : 'Contact for Price'),
      tip: points >= 5.0 ? 'Clear pricing and unit specified.' : 'Add a clear price and pricing unit (e.g. per piece, per meter, per day) to build buyer confidence.'
    }
  end

  def evaluate_trust
    points = 0.0
    is_doc_verified = @seller&.document_verified == true
    has_carbon_code = @seller&.carbon_code_id.present?
    has_good_reviews = (@stats&.review_count.to_i > 0) && (@stats&.avg_rating.to_f >= 4.0)

    points += 6.0 if is_doc_verified
    points += 2.0 if has_carbon_code
    points += 2.0 if has_good_reviews

    {
      points: points,
      max_points: 10.0,
      document_verified: is_doc_verified,
      carbon_code_verified: has_carbon_code,
      review_rating: @stats&.avg_rating.to_f,
      status: points >= 8.0 ? 'High Trust' : (points >= 6.0 ? 'Verified' : 'Unverified'),
      tip: is_doc_verified ? 'Seller identity verified.' : 'Submit seller verification documents in your profile to earn +6 trust points.'
    }
  end

  def evaluate_engagement
    reveals = @stats&.reveal_details_7d.to_i
    clicks = @stats&.click_count.to_i
    inquiries = @stats&.message_seller_7d.to_i + @stats&.quote_request_7d.to_i + @stats&.callback_request_7d.to_i
    wishlists = @stats&.wishlist_count.to_i + @stats&.add_to_cart_7d.to_i

    reveals_pts = [Math.log(reveals + 1) * 6.0, 18.0].min
    clicks_pts = [Math.log(clicks + 1) * 3.5, 12.0].min
    inquiries_pts = [Math.log(inquiries + 1) * 4.0, 6.0].min
    wishlists_pts = [Math.log(wishlists + 1) * 2.0, 4.0].min

    total_engagement = (reveals_pts + clicks_pts + inquiries_pts + wishlists_pts).round(1)

    {
      points: total_engagement,
      max_points: 40.0,
      reveals_7d: reveals,
      clicks: clicks,
      inquiries_7d: inquiries,
      wishlists: wishlists,
      status: total_engagement >= 25.0 ? 'Hot Listing' : (total_engagement >= 10.0 ? 'Active Interest' : 'New / Quiet'),
      tip: 'Earned automatically as buyers click, reveal contact details, and send inquiries.'
    }
  end

  def evaluate_freshness
    age_in_days = (Time.current.to_date - @ad.created_at.to_date).to_i
    points = if age_in_days <= 7
               15.0
             elsif age_in_days <= 21
               10.0
             elsif age_in_days <= 60
               5.0
             else
               0.0
             end

    {
      points: points,
      max_points: 15.0,
      age_days: age_in_days,
      status: points >= 15.0 ? 'Brand New' : (points >= 10.0 ? 'Fresh' : (points >= 5.0 ? 'Active' : 'Older Listing')),
      tip: points >= 15.0 ? 'Fresh upload bonus active.' : 'Keep inventory current. New and updated listings receive priority in search and rotation.'
    }
  end

  def build_recommendations(images, desc, specs, pricing, trust)
    recs = []
    if images[:points] < 15.0
      recs << { icon: 'camera', title: 'Upload 3+ Photos', desc: 'Add more photos from different angles to gain up to +15 pts', points: 15.0 - images[:points] }
    end
    if desc[:points] < 10.0
      recs << { icon: 'file-text', title: 'Expand Description', desc: 'Write at least 250 characters detailing condition, dimensions, and usage', points: 10.0 - desc[:points] }
    end
    if specs[:points] < 5.0
      recs << { icon: 'tag', title: 'Add Brand & Specifications', desc: 'Set the official brand and add technical specifications', points: 5.0 - specs[:points] }
    end
    if pricing[:points] < 5.0
      recs << { icon: 'dollar-sign', title: 'Specify Pricing Unit', desc: 'Set a price and select pricing unit (e.g. per item, per piece)', points: 5.0 - pricing[:points] }
    end
    if trust[:points] < 6.0
      recs << { icon: 'shield-check', title: 'Verify Seller Account', desc: 'Upload your business permit or national ID to unlock verified status', points: 6.0 - trust[:points] }
    end
    recs
  end
end
