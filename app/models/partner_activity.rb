# frozen_string_literal: true

class PartnerActivity < ApplicationRecord
  belongs_to :partner
  belongs_to :sales_user, optional: true

  # A single touchpoint with a partner. A partner can be called or visited
  # many times — each interaction is a row, with what was said in notes.
  enum :activity_type, {
    call: 0,
    visit: 1,
    whatsapp: 2,
    email: 3,
    meeting: 4,
    note: 5,
    status_change: 6,
    registered: 7
  }, default: :note, scopes: false

  # Types that count as an actual contact touchpoint (vs notes/system events)
  CONTACT_TYPES = %w[call visit whatsapp email meeting].freeze

  validates :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, created_at: :desc) }
  scope :contacts, -> { where(activity_type: CONTACT_TYPES) }
end
