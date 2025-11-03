class Conversation < ApplicationRecord
  belongs_to :admin, class_name: 'Admin', foreign_key: 'admin_id', optional: true
  belongs_to :buyer, class_name: 'Buyer', foreign_key: 'buyer_id', optional: true
  belongs_to :seller, class_name: 'Seller', foreign_key: 'seller_id', optional: true
  belongs_to :inquirer_seller, class_name: 'Seller', foreign_key: 'inquirer_seller_id', optional: true
  belongs_to :ad, optional: true

  has_many :messages, dependent: :destroy

  # Scopes to filter conversations with active (not deleted/blocked) participants
  # Using subqueries for better performance - only includes conversations where all participants are active
  scope :active_participants, -> {
    active_buyer_ids = Buyer.active.select(:id)
    active_seller_ids = Seller.active.select(:id)
    
    where(
      "(buyer_id IS NULL OR buyer_id IN (?)) AND " \
      "(seller_id IS NULL OR seller_id IN (?)) AND " \
      "(inquirer_seller_id IS NULL OR inquirer_seller_id IN (?))",
      active_buyer_ids,
      active_seller_ids,
      active_seller_ids
    )
  }

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
    if buyer_id.present? && !Buyer.active.exists?(buyer_id)
      errors.add(:buyer_id, 'Buyer does not exist or is inactive')
    end
  end

  def seller_exists_if_present
    if seller_id.present? && !Seller.active.exists?(seller_id)
      errors.add(:seller_id, 'Seller does not exist or is inactive')
    end
    if inquirer_seller_id.present? && !Seller.active.exists?(inquirer_seller_id)
      errors.add(:inquirer_seller_id, 'Inquirer seller does not exist or is inactive')
    end
  end

  def admin_exists_if_present
    if admin_id.present? && !Admin.exists?(admin_id)
      errors.add(:admin_id, 'Admin does not exist')
    end
  end
end

