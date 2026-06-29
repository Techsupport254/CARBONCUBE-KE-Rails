class CallRecord < ApplicationRecord
  belongs_to :customer, polymorphic: true, optional: true
  belongs_to :sales_user, optional: true

  # Status: 0=pending, 1=active, 2=completed, 3=missed, 4=abandoned
  enum status: { 
    pending: 0, 
    active: 1, 
    completed: 2, 
    missed: 3,
    abandoned: 4
  }

  # Call Type: 0=inbound, 1=outbound
  enum call_type: { 
    inbound: 0, 
    outbound: 1 
  }

  validates :status, presence: true
  validates :call_type, presence: true
  validates :rating_token, uniqueness: true, allow_nil: true

  before_create :generate_rating_token

  private

  def generate_rating_token
    self.rating_token = SecureRandom.hex(16) if rating_token.blank?
  end
end
