# app/models/seller.rb
class Seller < ApplicationRecord
  before_validation :normalize_email

  has_secure_password validations: false
  has_and_belongs_to_many :categories
  has_many :ads
  has_many :reviews, through: :ads
  has_many :wish_lists, dependent: :destroy
  has_many :wish_listed_ads, through: :wish_lists, source: :ad
  has_many :sent_messages, as: :sender, class_name: 'Message'
  has_many :conversations
  has_many :password_otps, as: :otpable, dependent: :destroy
  has_many :seller_documents, dependent: :destroy
  has_one :categories_seller
  has_one :category, through: :categories_seller
  has_one :seller_tier
  has_one :tier, through: :seller_tier
  
  belongs_to :county
  belongs_to :sub_county
  belongs_to :age_group
  belongs_to :document_type, optional: true

  validates :county_id, presence: true
  validates :sub_county_id, presence: true
  validates :fullname, presence: true
  validates :phone_number, presence: true, uniqueness: true, length: { is: 10, message: "must be exactly 10 digits" },
            format: { with: /\A\d{10}\z/, message: "should only contain numbers" }, unless: :oauth_user?
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :enterprise_name, presence: true, uniqueness: { case_sensitive: false }
  validates :location, presence: true
  validates :business_registration_number, length: { minimum: 1 }, allow_blank: true, uniqueness: true, allow_nil: true
  validates :username, presence: true, uniqueness: true, allow_blank: true,
            format: { with: /\A[a-zA-Z0-9_]{3,20}\z/, 
                      message: "must be 3-20 characters and contain only letters, numbers, and underscores (no spaces or hyphens)" }
  validates :age_group, presence: true
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validate :password_strength, if: :password_required?
  # validates :tier, inclusion: { in: %w[Free Basic Standard Premium] }

  # Callbacks for cache invalidation
  after_save :invalidate_caches
  after_destroy :invalidate_caches
  
  # Auto-delete ads when seller is deleted
  before_destroy :mark_ads_as_deleted

  def calculate_mean_rating
    # Use cached reviews if available, otherwise calculate
    if reviews.loaded?
      reviews.any? ? reviews.sum(&:rating).to_f / reviews.size : 0.0
    else
      reviews.average(:rating).to_f
    end
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

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
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
