class SalesUser < ApplicationRecord
  has_many :carbon_codes, as: :associable, dependent: :nullify

  has_secure_password
  has_many :password_otps, as: :otpable, dependent: :destroy
  validates :email, presence: true, uniqueness: true
  validates :phone_number, length: { is: 10 },
            format: { with: /\A\d{10}\z/ },
            allow_blank: true

  def deleted?
    false
  end
  
  def user_type
    'sales'
  end
end
