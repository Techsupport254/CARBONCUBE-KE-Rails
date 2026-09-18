# frozen_string_literal: true

# A person at a partner organization — the relationship for non-selling
# partners (NCBA Loop account managers) and extra contacts for selling ones.
class PartnerContact < ApplicationRecord
  belongs_to :partner
  has_many :invites, as: :invitee, class_name: 'PartnerInvite', dependent: :destroy

  validates :name, presence: true

  before_validation :normalize_phone_number
  after_save :demote_other_primaries, if: :is_primary?

  scope :primary, -> { where(is_primary: true) }
  scope :update_recipients, -> { where(receives_updates: true) }

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

  # Only one primary contact per partner — unset the flag on the others.
  def demote_other_primaries
    partner.contacts.where(is_primary: true).where.not(id: id).update_all(is_primary: false)
  end
end
