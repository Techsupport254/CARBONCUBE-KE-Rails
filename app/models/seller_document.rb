# app/models/seller_document.rb
class SellerDocument < ApplicationRecord
  belongs_to :seller
  belongs_to :document_type

  validates :document_url, presence: true
  validates :document_expiry_date, presence: true
  validates :seller_id, uniqueness: { scope: :document_type_id }

  scope :verified, -> { where(document_verified: true) }
  scope :expired, -> { where('document_expiry_date < ?', Date.current) }
  scope :expiring_soon, -> { where('document_expiry_date BETWEEN ? AND ?', Date.current, 30.days.from_now) }

  def expired?
    document_expiry_date < Date.current
  end

  def expiring_soon?
    document_expiry_date <= 30.days.from_now && document_expiry_date >= Date.current
  end
end
