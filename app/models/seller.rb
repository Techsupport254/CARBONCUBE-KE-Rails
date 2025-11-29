# app/models/seller.rb
class Seller < ApplicationRecord
  after_create :associate_guest_clicks
  before_create :generate_uuid
  before_validation :normalize_email
  before_validation :normalize_username
  
  # Store device hash temporarily for association (set via attr_accessor)
  attr_accessor :device_hash_for_association

  has_secure_password validations: false
  has_and_belongs_to_many :categories
  has_many :ads
  has_many :reviews, through: :ads
  has_many :wish_lists, dependent: :destroy
  has_many :wish_listed_ads, through: :wish_lists, source: :ad
  has_many :sent_messages, as: :sender, class_name: 'Message'
  has_many :conversations, dependent: :destroy
  has_many :password_otps, as: :otpable, dependent: :destroy
  has_many :seller_documents, dependent: :destroy
  has_many :offers, dependent: :destroy
  has_many :review_requests, dependent: :destroy
  has_one :categories_seller
  has_one :category, through: :categories_seller
  has_one :seller_tier
  has_one :tier, through: :seller_tier
  
  belongs_to :county, optional: true
  belongs_to :sub_county, optional: true
  belongs_to :age_group, optional: true
  belongs_to :document_type, optional: true

  validates :county_id, presence: true, unless: :oauth_user?
  validates :sub_county_id, presence: true, unless: :oauth_user?
  validates :fullname, presence: true
  validates :phone_number, presence: true, uniqueness: true, length: { is: 10, message: "must be exactly 10 digits" },
            format: { with: /\A\d{10}\z/, message: "should only contain numbers" }, unless: :oauth_user?
  # Secondary phone number is optional
  validates :secondary_phone_number, length: { is: 10, message: "must be exactly 10 digits" },
            format: { with: /\A\d{10}\z/, message: "should only contain numbers" }, 
            allow_blank: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :enterprise_name, presence: true, uniqueness: { case_sensitive: false }, unless: :oauth_user?
  validates :location, presence: true, unless: :oauth_user?
  validates :business_registration_number, length: { minimum: 1 }, allow_blank: true, uniqueness: true, allow_nil: true
  validates :username, uniqueness: true, allow_blank: true,
            format: { with: /\A[a-zA-Z0-9_-]{3,20}\z/, 
                      message: "must be 3-20 characters and contain only letters, numbers, underscores, and hyphens (no spaces)" },
            if: -> { username.present? }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validate :password_strength, if: :password_required?
  # validates :tier, inclusion: { in: %w[Free Basic Standard Premium] }

  # Scopes
  scope :active, -> { where(deleted: false, blocked: false) }
  scope :not_deleted, -> { where(deleted: false) }
  scope :not_blocked, -> { where(blocked: false) }

  # Callbacks for cache invalidation
  after_save :invalidate_caches
  after_destroy :invalidate_caches
  
  # Auto-delete ads when seller is deleted
  before_destroy :mark_ads_as_deleted
  
  # Auto-verify documents for 2025 sellers
  before_save :auto_verify_document_for_2025_sellers

  def calculate_mean_rating
    # Use cached reviews if available, otherwise calculate
    if reviews.loaded?
      reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
    else
      reviews.average(:rating).to_f
    end
  end

  # Alias for compatibility with areas expecting average_rating
  def average_rating
    calculate_mean_rating
  end

  def category_names
    categories.pluck(:name)
  end

  def check_and_block
    if calculate_mean_rating < 3.0
      update(blocked: true)
    else
      update(blocked: false)
    end
  end

  # Soft delete ads when seller is deleted
  def mark_ads_as_deleted
    ads.update_all(deleted: true)
  end

  def wish_list_ad(ad)
    wish_lists.create(ad: ad) unless wish_listed?(ad)
  end

  def unwish_list_ad(ad)
    wish_lists.find_by(ad: ad)&.destroy
  end

  def wish_listed?(ad)
    wish_listed_ads.include?(ad)
  end

  def password_required?
    # OAuth users don't need passwords
    return false if provider.present? || uid.present?
    
    new_record? || password.present?
  end

  def oauth_user?
    provider.present? || uid.present?
  end

  def ads_count
    ads.where(deleted: false).count
  end
  
  def deleted?
    deleted == true
  end
  
  def user_type
    'seller'
  end

  # Update last active timestamp
  def update_last_active!
    update_column(:last_active_at, Time.current)
  end

  # Associate guest click events with this seller based on device hash
  def associate_guest_clicks
    return if new_record? # Only run after save
    
    # Use device_hash_for_association if provided, otherwise let service find it
    GuestClickAssociationService.associate_clicks_with_user(self, device_hash_for_association)
  rescue => e
    # Don't fail seller creation if association fails
    Rails.logger.error "Failed to associate guest clicks during seller creation: #{e.message}" if defined?(Rails.logger)
  end

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.blank?
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_username
    return unless username.present?
    
    # Convert spaces to hyphens and remove any other invalid characters
    # Keep only letters, numbers, underscores, and hyphens
    normalized = username.to_s.strip
      .gsub(/\s+/, '-')  # Replace spaces with hyphens
      .gsub(/[^a-zA-Z0-9_-]/, '')  # Remove any other invalid characters
      .downcase
    
    # Remove consecutive hyphens/underscores
    normalized = normalized.gsub(/[-_]{2,}/, '-')
    
    # Remove leading/trailing hyphens and underscores
    normalized = normalized.gsub(/^[-_]+|[-_]+$/, '')
    
    # Ensure it's between 3-20 characters
    if normalized.length < 3
      # If too short, pad with numbers
      normalized = normalized + (1..(3 - normalized.length)).map { rand(0..9) }.join
    elsif normalized.length > 20
      # If too long, truncate
      normalized = normalized[0..19]
    end
    
    self.username = normalized if normalized.present?
  end

  def password_strength
    return unless password.present?

    # Check against common weak passwords
    common_passwords = %w[
      password 123456 123456789 qwerty abc123 password123 admin 12345678
      letmein welcome monkey dragon master hello login passw0rd 123123
      welcome123 1234567 12345 1234 111111 000000 1234567890
    ]

    if common_passwords.include?(password.downcase)
      errors.add(:password, "is too common. Please choose a more unique password.")
    end

    # Check for repeated characters (e.g., "aaaaaa", "111111")
    if password.match?(/(.)\1{3,}/)
      errors.add(:password, "contains too many repeated characters.")
    end

    # Check for sequential characters (e.g., "123456", "abcdef")
    if password.match?(/(0123456789|abcdefghijklmnopqrstuvwxyz|qwertyuiopasdfghjklzxcvbnm)/i)
      errors.add(:password, "contains sequential characters which are easy to guess.")
    end

    # Check if password contains user's email or username
    if email.present? && password.downcase.include?(email.split('@').first.downcase)
      errors.add(:password, "should not contain your email address.")
    end

    if username.present? && password.downcase.include?(username.downcase)
      errors.add(:password, "should not contain your username.")
    end
  end

  def auto_verify_document_for_2025_sellers
    # Automatically verify documents for sellers registered in 2025
    # Sales team confirms all 2025 registrations physically, so all should be verified
    # Check if current year is 2025 (for new records) or if seller was created in 2025 (for updates)
    seller_year = new_record? ? Time.current.year : (created_at&.year || Time.current.year)
    if seller_year == 2025 && !document_verified?
      self.document_verified = true
      Rails.logger.info "✅ Auto-verifying document for 2025 seller #{id || 'new'} (sales team confirmed physically)"
    end
  end

  def invalidate_caches
    # Invalidate related caches when seller is updated or deleted
    Rails.cache.delete_matched("buyer_ads_*")
    Rails.cache.delete_matched("search_*")
    Rails.cache.delete_matched("balanced_ads_*")
    Rails.cache.delete_matched("related_ads_*")
    
    # Invalidate category and subcategory caches
          Rails.cache.delete('buyer_categories_with_ads_count')
      Rails.cache.delete('buyer_category_analytics')
    Rails.cache.delete('buyer_subcategories_all')
  end
end
