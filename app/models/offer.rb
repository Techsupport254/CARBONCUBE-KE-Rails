class Offer < ApplicationRecord
  # Associations
  belongs_to :seller
  has_many :offer_ads, dependent: :destroy
  has_many :ads, through: :offer_ads
  
  # Enums
  enum status: {
    draft: 'draft',
    active: 'active', 
    paused: 'paused',
    expired: 'expired',
    scheduled: 'scheduled'
  }
  
  # Offer Types: Promotional offers for B2B/Industrial marketplace
  # Categories: Automotive Parts, Computer Parts, Filtration, Hardware Tools, Equipment Leasing
  # These offers apply to ALL categories - sellers choose which products to include
  enum offer_type: {
    # Flash & Limited Time Offers
    flash_sale: 'flash_sale',                      # Short-duration sales (hours/days)
    limited_time_offer: 'limited_time_offer',      # Any time-limited promotion
    daily_deal: 'daily_deal',                      # Daily special offers
    weekend_sale: 'weekend_sale',                  # Weekend-specific promotions
    monthly_special: 'monthly_special',            # Monthly promotional offers
    
    # Major Shopping Events (Relevant for Kenya/Africa)
    black_friday: 'black_friday',                  # Black Friday sales
    cyber_monday: 'cyber_monday',                  # Cyber Monday tech deals
    boxing_day: 'boxing_day',                      # Boxing Day sales
    
    # Seasonal & Holiday Promotions (Kenya-focused)
    new_year: 'new_year',                          # New Year promotions
    easter: 'easter',                              # Easter sales
    christmas: 'christmas',                        # Christmas promotions
    independence_day: 'independence_day',          # Jamhuri Day (Dec 12) / Madaraka Day (June 1)
    end_of_year: 'end_of_year',                   # End of year clearance
    mid_year_sale: 'mid_year_sale',               # Mid-year promotions
    
    # Inventory & Stock Management
    clearance: 'clearance',                        # Clearance sale
    stock_clearance: 'stock_clearance',           # Stock liquidation
    overstock_sale: 'overstock_sale',             # Excess inventory sale
    warehouse_sale: 'warehouse_sale',             # Warehouse clearance
    discontinued_items: 'discontinued_items',      # Discontinued product sale
    
    # Product-Specific Offers
    new_arrival: 'new_arrival',                    # New product launch
    new_stock: 'new_stock',                        # Newly stocked items
    restocked_items: 'restocked_items',           # Back in stock
    exclusive_items: 'exclusive_items',           # Exclusive products
    imported_goods: 'imported_goods',             # Imported items sale
    
    # Business & Bulk Offers
    bulk_discount: 'bulk_discount',                # Volume/bulk discounts
    wholesale_pricing: 'wholesale_pricing',        # Wholesale rates
    trade_discount: 'trade_discount',             # Trade/contractor discounts
    business_special: 'business_special',         # B2B exclusive offers
    contract_pricing: 'contract_pricing',         # Special contract rates
    
    # Customer-Specific Offers
    loyalty_reward: 'loyalty_reward',              # Repeat customer rewards
    first_time_buyer: 'first_time_buyer',         # New customer welcome
    vip_offer: 'vip_offer',                       # VIP customer exclusive
    referral_bonus: 'referral_bonus',             # Referral incentives
    
    # Special Promotions
    free_shipping: 'free_shipping',                # Free delivery offer
    free_installation: 'free_installation',        # Free installation service
    bundle_deal: 'bundle_deal',                    # Package deals
    combo_offer: 'combo_offer',                    # Combo packages
    buy_more_save_more: 'buy_more_save_more',     # Tiered volume discounts
    
    # Custom
    custom: 'custom'                               # Seller-defined custom offer
  }
  
  enum discount_type: {
    percentage: 'percentage',                    # X% off
    fixed_amount: 'fixed_amount',                # $X off
    buy_x_get_y: 'buy_x_get_y',                 # BOGO deals
    buy_x_get_y_percent_off: 'buy_x_get_y_percent_off',  # Buy 2 get 50% off
    free_shipping: 'free_shipping',              # Free shipping
    bundle_discount: 'bundle_discount',          # Bundle deals
    tiered_discount: 'tiered_discount',          # Buy more, save more
    free_gift_with_purchase: 'free_gift_with_purchase',  # Free gift
    cashback: 'cashback',                        # % cashback
    loyalty_points: 'loyalty_points',            # Earn points
    volume_discount: 'volume_discount',          # Bulk pricing
    first_order_discount: 'first_order_discount', # New customer
    minimum_purchase: 'minimum_purchase'         # Spend $X, save $Y
  }, _prefix: :discount
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :offer_type, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  # Offer-level discount is optional - sellers set individual discounts per product
  # validates :discount_percentage, presence: true, if: -> { discount_type == 'percentage' }
  # validates :fixed_discount_amount, presence: true, if: -> { discount_type == 'fixed_amount' }
  validate :end_time_after_start_time
  validate :valid_discount_configuration
  validate :valid_recurrence_configuration
  
  # Scopes
  scope :active_now, -> { where(status: 'active').where('start_time <= ? AND end_time >= ?', Time.current, Time.current) }
  scope :featured, -> { where(featured: true) }
  scope :homepage_visible, -> { where(show_on_homepage: true) }
  scope :by_type, ->(type) { where(offer_type: type) }
  scope :upcoming, -> { where(status: 'scheduled').where('start_time > ?', Time.current) }
  scope :expired, -> { where('end_time < ?', Time.current) }
  scope :by_priority, -> { order(priority: :desc, created_at: :desc) }
  
  # Callbacks
  before_save :set_defaults
  after_save :update_status_based_on_timing
  after_save :notify_status_change, if: :saved_change_to_status?
  
  # Methods
  def active?
    status == 'active' && Time.current.between?(start_time, end_time)
  end
  
  def upcoming?
    status == 'scheduled' && start_time > Time.current
  end
  
  def expired?
    end_time < Time.current
  end
  
  def can_be_activated?
    status.in?(['draft', 'scheduled', 'paused']) && start_time <= Time.current && end_time >= Time.current
  end
  
  def time_remaining
    return 0 if expired?
    (end_time - Time.current).to_i
  end
  
  def time_until_start
    return 0 if start_time <= Time.current
    (start_time - Time.current).to_i
  end
  
  def duration_in_hours
    ((end_time - start_time) / 1.hour).round(2)
  end
  
  def progress_percentage
    return 0 if start_time > Time.current
    return 100 if expired?
    
    total_duration = end_time - start_time
    elapsed = Time.current - start_time
    ((elapsed / total_duration) * 100).round(2)
  end
  
  def calculate_discount(original_price)
    case discount_type
    when 'percentage'
      original_price * (discount_percentage / 100.0)
    when 'fixed_amount'
      [fixed_discount_amount, original_price].min
    when 'buy_x_get_y'
      # Implement buy X get Y logic based on discount_config
      calculate_buy_x_get_y_discount(original_price)
    else
      0
    end
  end
  
  def final_price(original_price)
    discount = calculate_discount(original_price)
    [original_price - discount, 0].max
  end
  
  def is_eligible_for_product?(product)
    return false unless active?
    
    # Check category targeting
    if target_categories.present? && target_categories.any?
      return false unless target_categories.include?(product.category_id)
    end
    
    # Check seller targeting
    if target_sellers.present? && target_sellers.any?
      return false unless target_sellers.include?(product.seller_id)
    end
    
    # Check product targeting
    if target_products.present? && target_products.any?
      return false unless target_products.include?(product.id)
    end
    
    # Check minimum order amount
    if minimum_order_amount.present?
      return false if product.price < minimum_order_amount
    end
    
    true
  end
  
  def increment_view_count!
    increment!(:view_count)
  end
  
  def increment_click_count!
    increment!(:click_count)
  end
  
  def increment_conversion_count!
    increment!(:conversion_count)
  end
  
  def add_revenue!(amount)
    increment!(:revenue_generated, amount)
  end
  
  def conversion_rate
    return 0 if click_count.zero?
    (conversion_count.to_f / click_count * 100).round(2)
  end
  
  def click_through_rate
    return 0 if view_count.zero?
    (click_count.to_f / view_count * 100).round(2)
  end
  
  # Class methods for common offer types
  def self.create_black_friday_offer(attributes = {})
    create!(
      {
        name: 'Black Friday Sale',
        description: 'Huge discounts on Black Friday!',
        offer_type: 'black_friday',
        banner_color: '#000000',
        badge_color: '#ff0000',
        icon_name: 'bolt',
        badge_text: 'BLACK FRIDAY',
        discount_type: 'percentage',
        featured: true,
        priority: 100
      }.merge(attributes)
    )
  end
  
  def self.create_cyber_monday_offer(attributes = {})
    create!(
      {
        name: 'Cyber Monday Deals',
        description: 'Tech deals you can\'t miss!',
        offer_type: 'cyber_monday',
        banner_color: '#1e40af',
        badge_color: '#3b82f6',
        icon_name: 'laptop',
        badge_text: 'CYBER MONDAY',
        discount_type: 'percentage',
        featured: true,
        priority: 90
      }.merge(attributes)
    )
  end
  
  def self.create_flash_sale_offer(attributes = {})
    create!(
      {
        name: 'Flash Sale',
        description: 'Limited time offers!',
        offer_type: 'flash_sale',
        banner_color: '#dc2626',
        badge_color: '#fbbf24',
        icon_name: 'bolt',
        badge_text: 'FLASH SALE',
        discount_type: 'percentage',
        featured: true,
        priority: 80
      }.merge(attributes)
    )
  end
  
  def self.create_clearance_offer(attributes = {})
    create!(
      {
        name: 'Clearance Sale',
        description: 'Clearance items at unbeatable prices!',
        offer_type: 'clearance',
        banner_color: '#7c2d12',
        badge_color: '#f97316',
        icon_name: 'tag',
        badge_text: 'CLEARANCE',
        discount_type: 'percentage',
        featured: true,
        priority: 70
      }.merge(attributes)
    )
  end
  
  # Additional popular offer types
  def self.create_bogo_offer(attributes = {})
    create!(
      {
        name: 'Buy One Get One',
        description: 'Buy one, get one free or discounted!',
        offer_type: 'limited_time_offer',
        banner_color: '#059669',
        badge_color: '#10b981',
        icon_name: 'gift',
        badge_text: 'BOGO',
        discount_type: 'buy_x_get_y',
        featured: true,
        priority: 75
      }.merge(attributes)
    )
  end
  
  def self.create_free_shipping_offer(attributes = {})
    create!(
      {
        name: 'Free Shipping',
        description: 'Free shipping on all orders!',
        offer_type: 'limited_time_offer',
        banner_color: '#0891b2',
        badge_color: '#06b6d4',
        icon_name: 'truck',
        badge_text: 'FREE SHIPPING',
        discount_type: 'free_shipping',
        featured: true,
        priority: 65
      }.merge(attributes)
    )
  end
  
  def self.create_seasonal_offer(attributes = {})
    create!(
      {
        name: 'Seasonal Sale',
        description: 'Seasonal discounts and offers!',
        offer_type: 'seasonal',
        banner_color: '#7c3aed',
        badge_color: '#a78bfa',
        icon_name: 'calendar',
        badge_text: 'SEASONAL',
        discount_type: 'percentage',
        featured: true,
        priority: 60
      }.merge(attributes)
    )
  end
  
  def self.create_bundle_offer(attributes = {})
    create!(
      {
        name: 'Bundle Deal',
        description: 'Save more when you bundle!',
        offer_type: 'bulk_discount',
        banner_color: '#db2777',
        badge_color: '#ec4899',
        icon_name: 'box',
        badge_text: 'BUNDLE',
        discount_type: 'bundle_discount',
        featured: true,
        priority: 55
      }.merge(attributes)
    )
  end
  
  def self.create_loyalty_offer(attributes = {})
    create!(
      {
        name: 'Loyalty Reward',
        description: 'Exclusive rewards for loyal customers!',
        offer_type: 'loyalty_reward',
        banner_color: '#ea580c',
        badge_color: '#f97316',
        icon_name: 'star',
        badge_text: 'VIP',
        discount_type: 'percentage',
        featured: false,
        priority: 50
      }.merge(attributes)
    )
  end
  
  def self.create_new_customer_offer(attributes = {})
    create!(
      {
        name: 'Welcome Offer',
        description: 'Special discount for first-time buyers!',
        offer_type: 'first_time_buyer',
        banner_color: '#0369a1',
        badge_color: '#0ea5e9',
        icon_name: 'user-plus',
        badge_text: 'NEW CUSTOMER',
        discount_type: 'first_order_discount',
        featured: false,
        priority: 45
      }.merge(attributes)
    )
  end
  
  def self.create_weekend_sale(attributes = {})
    create!(
      {
        name: 'Weekend Sale',
        description: 'Special weekend discounts!',
        offer_type: 'weekend_sale',
        banner_color: '#be123c',
        badge_color: '#f43f5e',
        icon_name: 'clock',
        badge_text: 'WEEKEND',
        discount_type: 'percentage',
        featured: true,
        priority: 55
      }.merge(attributes)
    )
  end
  
  def self.create_cashback_offer(attributes = {})
    create!(
      {
        name: 'Cashback Offer',
        description: 'Get cashback on your purchase!',
        offer_type: 'cashback',
        banner_color: '#065f46',
        badge_color: '#10b981',
        icon_name: 'money-bill',
        badge_text: 'CASHBACK',
        discount_type: 'cashback',
        featured: true,
        priority: 60
      }.merge(attributes)
    )
  end
  
  # Generic custom offer creator
  def self.create_custom_offer(attributes = {}, name:, description:)
    create!(
      {
        name: name,
        description: description,
        offer_type: 'custom',
        banner_color: '#6b7280',
        badge_color: '#9ca3af',
        icon_name: 'tag',
        badge_text: 'OFFER',
        discount_type: 'percentage',
        featured: false,
        priority: 40
      }.merge(attributes)
    )
  end
  
  private
  
  def set_defaults
    self.banner_color ||= '#dc2626'
    self.badge_color ||= '#fbbf24'
    self.icon_name ||= 'bolt'
    self.badge_text ||= 'SALE'
    self.cta_text ||= 'Shop Now'
    self.priority ||= 0
  end
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end
  
  def valid_discount_configuration
    case discount_type
    when 'percentage'
      # Offer-level discount is optional - discounts are set per product in offer_ads
      if discount_percentage.present? && (discount_percentage <= 0 || discount_percentage > 100)
        errors.add(:discount_percentage, 'must be between 0 and 100')
      end
    when 'fixed_amount'
      if fixed_discount_amount.present? && fixed_discount_amount <= 0
        errors.add(:fixed_discount_amount, 'must be greater than 0')
      end
    end
  end
  
  def valid_recurrence_configuration
    return unless is_recurring
    
    if recurrence_pattern.blank?
      errors.add(:recurrence_pattern, 'is required for recurring offers')
    end
  end
  
  def update_status_based_on_timing
    return unless start_time && end_time
    
    if Time.current < start_time
      update_column(:status, 'scheduled') unless status == 'scheduled'
    elsif Time.current.between?(start_time, end_time)
      update_column(:status, 'active') if status.in?(['scheduled', 'paused'])
    elsif Time.current > end_time
      update_column(:status, 'expired') unless status == 'expired'
    end
  end
  
  def notify_status_change
    # Implement notification logic here
    # Could send emails, push notifications, etc.
  end
  
  def calculate_buy_x_get_y_discount(original_price)
    # Implement buy X get Y logic
    # This would depend on the discount_config JSON structure
    0
  end
end
