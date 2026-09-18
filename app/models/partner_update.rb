# frozen_string_literal: true

# A broadcast from a partner to its distributor network and contacts —
# price changes, announcements, promotions, restocks. Fan-out happens in
# PartnerUpdateFanoutJob after create.
class PartnerUpdate < ApplicationRecord
  belongs_to :partner
  belongs_to :sales_user, optional: true
  belongs_to :ad, optional: true

  enum :kind, {
    pricing: 0,
    announcement: 1,
    promotion: 2,
    restock: 3,
    other: 4
  }, default: :announcement, scopes: false

  validates :title, presence: true

  after_create_commit :enqueue_fanout

  private

  def enqueue_fanout
    PartnerUpdateFanoutJob.perform_later(id)
  end
end
