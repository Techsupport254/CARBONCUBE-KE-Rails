# app/models/buyer.rb
class Buyer < ApplicationRecord
  after_create :associate_guest_clicks
  before_create :generate_uuid
  before_validation :normalize_email
  before_validation :normalize_username
  before_validation :generate_username_from_fullname
  
  # Store device hash temporarily for association (set via attr_accessor)
  attr_accessor :device_hash_for_association

  has_secure_password validations: false

  has_many :reviews
  has_many :cart_items
  has_many :wish_lists, dependent: :destroy
  has_many :wish_listed_ads, through: :wish_lists, source: :ad
  has_many :sent_messages, as: :sender, class_name: 'Message'
  has_many :conversations, dependent: :destroy
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
            format: { with: /\A[a-zA-Z0-9_-]{3,20}\z/, 
                      message: "must be 3-20 characters and contain only letters, numbers, underscores, and hyphens (no spaces)" }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  # validates :zipcode, presence: true
  # validates :city, presence: true
  # validates :sub_county, presence: true
  validates :gender, inclusion: { in: %w(Male Female Other) }, allow_blank: true
  # validates :location, presence: true
  # Phone number is optional for regular signups (users can verify later)
  # Only validate format and uniqueness if phone number is provided
  validates :phone_number, uniqueness: true, length: { is: 10, message: "must be exactly 10 digits" },
            format: { with: /\A\d{10}\z/, message: "should only contain numbers" }, 
            allow_blank: true, unless: :oauth_user?
  
  # Secondary phone number is optional
  validates :secondary_phone_number, length: { is: 10, message: "must be exactly 10 digits" },
            format: { with: /\A\d{10}\z/, message: "should only contain numbers" }, 
            allow_blank: true
  
  # For OAuth users, phone number validation is still optional (users can verify later)
  # We don't enforce phone number requirement even for OAuth users

  attribute :cart_total_price, :decimal, default: 0

  # Scopes
  scope :active, -> { where(deleted: false, blocked: false) }
  scope :not_deleted, -> { where(deleted: false) }
  scope :not_blocked, -> { where(blocked: false) }


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
  
  def deleted?
    deleted == true
  end
  
  def user_type
    'buyer'
  end

  # Update last active timestamp
  def update_last_active!
    update_column(:last_active_at, Time.current)
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

  # Associate guest click events with this buyer based on device hash
  def associate_guest_clicks
    return if new_record? # Only run after save
    
    # Use device_hash_for_association if provided, otherwise let service find it
    GuestClickAssociationService.associate_clicks_with_user(self, device_hash_for_association)
  rescue => e
    # Don't fail buyer creation if association fails
    Rails.logger.error "Failed to associate guest clicks during buyer creation: #{e.message}" if defined?(Rails.logger)
  end

  private

  def generate_uuid
    if id.blank?
      generated_id = SecureRandom.uuid
      Rails.logger.info "🔧 Generating UUID for buyer: #{generated_id}"
      self.id = generated_id
    else
      Rails.logger.info "🔧 Buyer already has UUID: #{id}"
    end
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

  def generate_username_from_fullname
    # Only generate if username is blank and fullname is present
    return if username.present? || fullname.blank?
    
    # Extract first name from fullname
    first_name = fullname.to_s.strip.split.first
    
    # Clean the first name: remove special characters and spaces
    base_username = first_name.downcase.gsub(/[^a-z0-9]/, '')
    
    # Ensure minimum length of 3 characters
    base_username = "user#{rand(100..999)}" if base_username.length < 3
    
    # Truncate to 15 characters to leave room for numbers
    base_username = base_username[0..14]
    
    # Check for uniqueness and append numbers if needed
    generated_username = base_username
    counter = 1
    
    while Buyer.exists?(username: generated_username) || Seller.exists?(username: generated_username)
      generated_username = "#{base_username}#{counter}"
      counter += 1
      
      # If it gets too long, start over with a random suffix
      if generated_username.length > 20
        generated_username = "#{base_username[0..14]}#{rand(10..99)}"
        break
      end
    end
    
    self.username = generated_username
  end

  # Phone number validation removed - users can verify their accounts later

end
