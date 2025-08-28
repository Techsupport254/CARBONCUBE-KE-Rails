class Conversation < ApplicationRecord
  belongs_to :admin, class_name: 'Admin', foreign_key: 'admin_id', optional: true
  belongs_to :buyer, class_name: 'Buyer', foreign_key: 'buyer_id', optional: true
  belongs_to :seller, class_name: 'Seller', foreign_key: 'seller_id', optional: true
  belongs_to :ad, optional: true

  has_many :messages, dependent: :destroy

  # Validation for participant presence
  validate :at_least_one_participant_present
  validates :ad_id, uniqueness: { scope: [:buyer_id, :seller_id], message: "conversation already exists for this ad" }

  private

  def at_least_one_participant_present
    if admin_id.blank? && buyer_id.blank? && seller_id.blank?
      errors.add(:base, 'Conversation must have at least one participant (admin, buyer, or seller)')
    end
  end
end

