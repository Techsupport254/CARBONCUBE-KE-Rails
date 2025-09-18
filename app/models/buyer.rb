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
  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :age_group, presence: true
  # validates :zipcode, presence: true
  validates :city, presence: true
  # validates :sub_county, presence: true
  validates :gender, inclusion: { in: %w(Male Female Other) }
  # validates :location, presence: true
  validates :phone_number, presence: true, length: { is: 10, message: "must be exactly 10 digits" },
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

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
