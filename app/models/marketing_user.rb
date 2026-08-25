class MarketingUser < ApplicationRecord
  has_secure_password
  has_many :password_otps, as: :otpable, dependent: :destroy
  validates :email, presence: true, uniqueness: true
  validates :phone_number, length: { is: 10 },
            format: { with: /\A\d{10}\z/ },
            allow_blank: true
  
  scope :active, -> { where(active: true) }
  scope :deactivated, -> { where(active: false) }

  def deleted?
    !active?
  end

  def active?
    active != false
  end

  def deactivated?
    !active?
  end

  def deactivate!
    update(active: false, deactivated_at: Time.current)
  end

  def reactivate!
    update(active: true, deactivated_at: nil)
  end
  
  def user_type
    'marketing'
  end
end
