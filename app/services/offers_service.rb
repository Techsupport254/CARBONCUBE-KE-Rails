class OffersService
  include ActiveModel::Model
  
  attr_accessor :offer, :product, :buyer
  
  def initialize(offer:, product: nil, buyer: nil)
    @offer = offer
    @product = product
    @buyer = buyer
  end
  
  # Get all active offers for a product
  def self.active_offers_for_product(product)
    Offer.active_now.select do |offer|
      offer.is_eligible_for_product?(product)
    end.sort_by(&:priority).reverse
  end
  
  # Get the best offer for a product
  def self.best_offer_for_product(product)
    active_offers_for_product(product).first
  end
  
  # Calculate discounted price for a product
  def self.calculate_discounted_price(product)
    best_offer = best_offer_for_product(product)
    return product.price unless best_offer
    
    best_offer.final_price(product.price)
  end
  
  # Get products with active offers
  def self.products_with_offers(category_id: nil, limit: 20)
    # This would need to be implemented based on your product model
    # For now, returning a placeholder
    []
  end
  
  # Create seasonal offers automatically
  def self.create_seasonal_offers
    current_date = Date.current
    
    # Black Friday (last Friday of November)
    if current_date.month == 11 && current_date.day >= 20
      create_black_friday_offer unless Offer.where(offer_type: 'black_friday', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # Cyber Monday (Monday after Black Friday)
    if current_date.month == 11 && current_date.day >= 24
      create_cyber_monday_offer unless Offer.where(offer_type: 'cyber_monday', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # Christmas/Holiday offers
    if current_date.month == 12
      create_christmas_offer unless Offer.where(offer_type: 'christmas', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # New Year offers
    if current_date.month == 1
      create_new_year_offer unless Offer.where(offer_type: 'new_year', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # Valentine's Day
    if current_date.month == 2 && current_date.day >= 10
      create_valentines_offer unless Offer.where(offer_type: 'valentines', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # Mother's Day (second Sunday of May)
    if current_date.month == 5 && current_date.day >= 8
      create_mothers_day_offer unless Offer.where(offer_type: 'mothers_day', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # Father's Day (third Sunday of June)
    if current_date.month == 6 && current_date.day >= 15
      create_fathers_day_offer unless Offer.where(offer_type: 'fathers_day', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
    
    # Independence Day (December 12th for Kenya)
    if current_date.month == 12 && current_date.day >= 10
      create_independence_day_offer unless Offer.where(offer_type: 'independence_day', start_time: current_date.beginning_of_month..current_date.end_of_month).exists?
    end
  end
  
  # Create flash sale offers
  def self.create_flash_sale_offers
    # Create random flash sales throughout the day
    if rand(1..10) == 1 # 10% chance every time this is called
      Offer.create_flash_sale_offer(
        start_time: Time.current,
        end_time: Time.current + rand(2..6).hours,
        discount_percentage: rand(20..50),
        target_categories: Category.pluck(:id).sample(rand(1..3))
      )
    end
  end
  
  # Get trending offers based on performance
  def self.trending_offers(limit: 5)
    Offer.active_now
         .where('click_count > 0')
         .order('conversion_rate DESC, click_count DESC')
         .limit(limit)
  end
  
  # Get personalized offers for a buyer
  def self.personalized_offers_for_buyer(buyer, limit: 10)
    # This would analyze buyer's purchase history, preferences, etc.
    # For now, returning general active offers
    Offer.active_now
         .featured
         .by_priority
         .limit(limit)
  end
  
  # Track offer interaction
  def track_interaction(interaction_type)
    case interaction_type
    when 'view'
      @offer.increment_view_count!
    when 'click'
      @offer.increment_click_count!
    when 'conversion'
      @offer.increment_conversion_count!
      @offer.add_revenue!(@product.price) if @product
    end
  end
  
  # Check if buyer is eligible for offer
  def buyer_eligible?
    return true unless @buyer
    
    # Check usage limits
    if @offer.max_uses_per_customer.present?
      # This would need to track usage per buyer
      # For now, assuming unlimited
    end
    
    # Check minimum order amount
    if @offer.minimum_order_amount.present? && @product
      return false if @product.price < @offer.minimum_order_amount
    end
    
    true
  end
  
  # Apply offer to product
  def apply_to_product
    return @product.price unless buyer_eligible?
    
    @offer.final_price(@product.price)
  end
  
  private
  
  def self.create_black_friday_offer
    Offer.create_black_friday_offer(
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 3.days
    )
  end
  
  def self.create_cyber_monday_offer
    Offer.create_cyber_monday_offer(
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day
    )
  end
  
  def self.create_christmas_offer
    Offer.create!(
      name: 'Christmas Sale',
      description: 'Holiday deals and discounts!',
      offer_type: 'christmas',
      banner_color: '#dc2626',
      badge_color: '#fbbf24',
      icon_name: 'gift',
      badge_text: 'CHRISTMAS',
      discount_type: 'percentage',
      discount_percentage: 35.0,
      featured: true,
      priority: 85,
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 10.days
    )
  end
  
  def self.create_new_year_offer
    Offer.create!(
      name: 'New Year Sale',
      description: 'Start the year with great deals!',
      offer_type: 'new_year',
      banner_color: '#1e40af',
      badge_color: '#3b82f6',
      icon_name: 'star',
      badge_text: 'NEW YEAR',
      discount_type: 'percentage',
      discount_percentage: 25.0,
      featured: true,
      priority: 75,
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 7.days
    )
  end
  
  def self.create_valentines_offer
    Offer.create!(
      name: 'Valentine\'s Day Special',
      description: 'Perfect gifts for your loved ones!',
      offer_type: 'valentines',
      banner_color: '#ec4899',
      badge_color: '#f472b6',
      icon_name: 'heart',
      badge_text: 'VALENTINE\'S',
      discount_type: 'percentage',
      discount_percentage: 30.0,
      featured: true,
      priority: 80,
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 5.days
    )
  end
  
  def self.create_mothers_day_offer
    Offer.create!(
      name: 'Mother\'s Day Special',
      description: 'Show your love with perfect gifts!',
      offer_type: 'mothers_day',
      banner_color: '#7c3aed',
      badge_color: '#a78bfa',
      icon_name: 'heart',
      badge_text: 'MOTHER\'S DAY',
      discount_type: 'percentage',
      discount_percentage: 25.0,
      featured: true,
      priority: 70,
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 3.days
    )
  end
  
  def self.create_fathers_day_offer
    Offer.create!(
      name: 'Father\'s Day Special',
      description: 'Great gifts for dad!',
      offer_type: 'fathers_day',
      banner_color: '#059669',
      badge_color: '#10b981',
      icon_name: 'user',
      badge_text: 'FATHER\'S DAY',
      discount_type: 'percentage',
      discount_percentage: 25.0,
      featured: true,
      priority: 70,
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 3.days
    )
  end
  
  def self.create_independence_day_offer
    Offer.create!(
      name: 'Independence Day Sale',
      description: 'Celebrate Kenya with great deals!',
      offer_type: 'independence_day',
      banner_color: '#dc2626',
      badge_color: '#fbbf24',
      icon_name: 'flag',
      badge_text: 'INDEPENDENCE',
      discount_type: 'percentage',
      discount_percentage: 40.0,
      featured: true,
      priority: 90,
      start_time: Date.current.beginning_of_day,
      end_time: Date.current.end_of_day + 2.days
    )
  end
end
