class EmailOtp < ApplicationRecord
  # Ensure verified defaults to false
  before_validation :set_default_verified, on: :create
  
  def verified?
    verified == true
  end
  
  private
  
  def set_default_verified
    self.verified = false if verified.nil?
  end
end
