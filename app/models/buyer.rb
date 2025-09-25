# app/models/buyer.rb
class Buyer < ApplicationRecord
  before_validation :normalize_email

  has_secure_password

  has_many :reviews
  has_many :cart_items
  has_many :wish_lists, dependent: :destroy
  has_many :wish_listed_ads, through: :wish_lists, source: :ad
  has_many :sent_messages, as: :sender, class_name: 'Message'
  has_many :conversations
  has_many :click_events
  has_many :ad_searches
  has_many :password_otps, as: :otpable, dependent: :destroy

  belongs_to :sector, optional: true
  belongs_to :income, optional: true
  belongs_to :education, optional: true
  belongs_to :employment, optional: true
  belongs_to :sub_county, optional: true
  belongs_to :county, optional: true
  belongs_to :age_group, optional: true

  validates :fullname, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :username, presence: true, uniqueness: true, 
            format: { with: /\A[a-zA-Z0-9_]{3,20}\z/, 
                      message: "must be 3-20 characters and contain only letters, numbers, and underscores (no spaces or hyphens)" }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validate :password_strength, if: :password_required?
  validates :age_group, presence: true
  # validates :zipcode, presence: true
  # validates :city, presence: true
  # validates :sub_county, presence: true
  validates :gender, inclusion: { in: %w(Male Female Other) }
  # validates :location, presence: true
  validates :phone_number, presence: true, uniqueness: true, length: { is: 10, message: "must be exactly 10 digits" },
            format: { with: /\A\d{10}\z/, message: "should only contain numbers" }

  attribute :cart_total_price, :decimal, default: 0


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
    new_record? || password.present?
  end
  
  def deleted?
    deleted == true
  end
  
  def user_type
    'buyer'
  end

  def profile_completion_percentage
    # All fields (required + optional) for a more realistic completion percentage
    all_fields = [
      # Required fields
      fullname.present?,
      username.present?,
      email.present?,
      phone_number.present?,
      gender.present?,
      age_group_id.present?,
      # Optional fields
      location.present?,
      city.present?,
      county_id.present?,
      sub_county_id.present?,
      zipcode.present?,
      profile_picture.present?,
      income_id.present?,
      employment_id.present?,
      education_id.present?,
      sector_id.present?
    ]

    # Calculate completion based on all fields
    completed_fields = all_fields.count(true)
    total_completion = (completed_fields.to_f / all_fields.length * 100).round

    total_completion
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
end
