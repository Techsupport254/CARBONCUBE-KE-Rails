# frozen_string_literal: true

# A reseller in a partner's distribution network. Linked to a Seller account
# once onboarded — subscribed distributors get pricing + announcement updates.
class PartnerDistributor < ApplicationRecord
  belongs_to :partner
  belongs_to :seller, optional: true
  belongs_to :sales_user, optional: true
  has_many :invites, as: :invitee, class_name: 'PartnerInvite', dependent: :destroy

  enum :status, {
    invited: 0,
    active: 1,
    inactive: 2
  }, default: :invited, scopes: false

  validates :name, presence: true

  before_validation :normalize_phone_number

  scope :pricing_recipients, -> { where(status: 'active', notify_pricing: true).where.not(seller_id: nil) }
  scope :update_recipients, -> { where(status: 'active', notify_updates: true).where.not(seller_id: nil) }

  def normalize_phone_number
    return if phone.blank?

    digits = phone.gsub(/\D/, '')
    self.phone =
      if digits.start_with?('254') && digits.length == 12
        "0#{digits[3..]}"
      elsif digits.length == 9 && digits.start_with?('7', '1')
        "0#{digits}"
      else
        digits
      end
  end

  # Find a platform seller matching this distributor — phone suffix, then email.
  def matching_seller
    if phone.present?
      suffix = phone.gsub(/\D/, '')[-9..]
      if suffix.present? && suffix.length >= 9
        seller = Seller.find_by('phone_number LIKE ? OR secondary_phone_number LIKE ?',
                                "%#{suffix}", "%#{suffix}")
        return seller if seller
      end
    end

    Seller.find_by('LOWER(email) = ?', email.downcase.strip) if email.present?
  end

  def link_seller!(seller)
    update!(seller_id: seller.id)
  end

  def activate!
    update!(status: 'active')
  end

  def deactivate!
    update!(status: 'inactive')
  end

  def pending_invite
    invites.where(status: 'pending').order(created_at: :desc).first
  end
end
