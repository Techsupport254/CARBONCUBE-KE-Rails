class Conversation < ApplicationRecord
  belongs_to :admin, class_name: 'Admin', foreign_key: 'admin_id', optional: true
  belongs_to :buyer, class_name: 'Buyer', foreign_key: 'buyer_id', optional: true
  belongs_to :seller, class_name: 'Seller', foreign_key: 'seller_id', optional: true
  belongs_to :inquirer_seller, class_name: 'Seller', foreign_key: 'inquirer_seller_id', optional: true
  belongs_to :ad, optional: true

  has_many :messages, dependent: :destroy

  # Validation for participant presence
  validate :at_least_one_participant_present
  validate :buyer_exists_if_present
  validate :seller_exists_if_present
  validate :admin_exists_if_present
  validates :ad_id, uniqueness: { 
    scope: [:buyer_id, :seller_id, :inquirer_seller_id], 
    message: "conversation already exists for this ad with these participants" 
  }

  private

  def at_least_one_participant_present
    if admin_id.blank? && buyer_id.blank? && seller_id.blank? && inquirer_seller_id.blank?
      errors.add(:base, 'Conversation must have at least one participant (admin, buyer, seller, or inquirer_seller)')
    end
  end

  def buyer_exists_if_present
    if buyer_id.present? && !Buyer.exists?(buyer_id)
      errors.add(:buyer_id, 'Buyer does not exist')
    end
  end

  def seller_exists_if_present
    if seller_id.present? && !Seller.exists?(seller_id)
      errors.add(:seller_id, 'Seller does not exist')
    end
  end

  def admin_exists_if_present
    if admin_id.present? && !Admin.exists?(admin_id)
      errors.add(:admin_id, 'Admin does not exist')
    end
  end
end

