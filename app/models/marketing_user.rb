class MarketingUser < ApplicationRecord
  has_secure_password
  validates :email, presence: true, uniqueness: true
  
  def deleted?
    false
  end
  
  def user_type
    'marketing'
  end
end
