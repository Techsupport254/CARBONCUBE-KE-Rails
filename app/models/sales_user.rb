class SalesUser < ApplicationRecord
  has_secure_password
  validates :email, presence: true, uniqueness: true
  
  def deleted?
    false
  end
  
  def user_type
    'sales'
  end
end
