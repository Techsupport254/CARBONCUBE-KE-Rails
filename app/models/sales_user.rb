class SalesUser < ApplicationRecord
  has_many :carbon_codes, as: :associable, dependent: :nullify

  has_secure_password
  has_many :password_otps, as: :otpable, dependent: :destroy
  validates :email, presence: true, uniqueness: true

  def deleted?
    false
  end
  
  def user_type
    'sales'
  end
end
