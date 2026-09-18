# frozen_string_literal: true

class Partner < ApplicationRecord
  include ActorAttribution

  belongs_to :sales_user, optional: true
  belongs_to :seller, optional: true
  belongs_to :sales_brand, optional: true
  has_many :activities, -> { recent_first },
           class_name: 'PartnerActivity',
           inverse_of: :partner,
           dependent: :destroy
  has_many :contacts, -> { order(is_primary: :desc, created_at: :asc) },
           class_name: 'PartnerContact',
           inverse_of: :partner,
           dependent: :destroy
  has_many :distributors, -> { order(created_at: :asc) },
           class_name: 'PartnerDistributor',
           inverse_of: :partner,
           dependent: :destroy
  has_many :updates, -> { order(created_at: :desc) },
           class_name: 'PartnerUpdate',
           inverse_of: :partner,
           dependent: :destroy
  has_many :invites, as: :invitee, class_name: 'PartnerInvite', dependent: :destroy

  # What kind of business this partner is. Selling types can run a storefront
  # on the platform; the rest are relationship-only partners (NCBA Loop, etc).
  enum :partner_type, {
    brand_manufacturer: 0,
    distributor: 1,
    wholesaler: 2,
    retailer: 3,
    financier: 4,
    logistics: 5,
    service: 6,
    other: 7
  }, default: :brand_manufacturer, scopes: false

  # Partnership lifecycle — separate from the sales outreach statuses on
  # SalesBrand. A partner is a formalized relationship, not a prospect.
  enum :status, {
    negotiating: 0,
    active: 1,
    paused: 2,
    ended: 3
  }, default: :negotiating, scopes: false

  # Partner types whose business sells on the platform
  SELLING_TYPES = %w[brand_manufacturer distributor wholesaler retailer].freeze

  validates :name, presence: true

  before_validation :normalize_phone_number

  # Normalize Kenyan phone numbers the same way Seller/SalesBrand do, so
  # suffix matching against call logs and seller signups works.
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

  scope :with_follow_up, -> { where.not(follow_up_date: nil) }
  scope :follow_up_overdue, -> { with_follow_up.where(follow_up_date: ...Date.current) }
  scope :follow_up_today, -> { with_follow_up.where(follow_up_date: Date.current) }
  scope :follow_up_upcoming, -> { with_follow_up.where(follow_up_date: (Date.current + 1.day)..) }
  scope :selling, -> { where(partner_type: SELLING_TYPES) }

  scope :search, lambda { |query|
    return all if query.blank?

    term = "%#{query.to_s.downcase}%"
    where(
      'LOWER(name) LIKE :term OR LOWER(location) LIKE :term OR ' \
      'LOWER(contact_person) LIKE :term OR LOWER(description) LIKE :term OR ' \
      'phone LIKE :term OR LOWER(email) LIKE :term',
      term: term
    )
  }

  # Whether this partner sells on the platform (storefront + product uploads).
  def sells_on_platform?
    SELLING_TYPES.include?(partner_type)
  end

  # The most recent still-pending invite for this partner, if any.
  def pending_invite
    invites.where(status: 'pending').order(created_at: :desc).first
  end

  # Record a touchpoint (call, visit, whatsapp, …) and roll its effects up to
  # the partner's current-state fields — same convention as SalesBrand.
  # `user` may be a SalesUser or an Admin — only a SalesUser is written to
  # sales_user_id; an admin is attributed via the activity's actor_name.
  def record_activity!(type:, user:, occurred_at: nil, notes: nil, outcome: nil, follow_up_date: nil,
                       latitude: nil, longitude: nil)
    rep = sales_user_for(user)
    activity = activities.create!(
      activity_type: type,
      sales_user: rep,
      actor_name: actor_name_for(user),
      occurred_at: occurred_at.presence || Time.current,
      notes: notes,
      outcome: outcome,
      follow_up_date: follow_up_date,
      latitude: latitude,
      longitude: longitude
    )

    updates = {}
    updates[:sales_user_id] = rep.id if sales_user_id.nil? && rep
    if PartnerActivity::CONTACT_TYPES.include?(activity.activity_type)
      updates[:last_contacted_at] = activity.occurred_at
    end
    if activity.follow_up_date.present?
      updates[:follow_up_date] = activity.follow_up_date
      updates[:follow_up_note] = activity.notes if activity.notes.present?
    elsif PartnerActivity::CONTACT_TYPES.include?(activity.activity_type) &&
          self.follow_up_date.present?
      updates[:follow_up_date] = nil
      updates[:follow_up_note] = nil
    end
    update!(updates) if updates.any?

    activity
  end

  # Raised when a status transition is missing its required data
  class TransitionError < StandardError; end

  # Apply a partnership lifecycle change:
  # - active: stamps signed_on if not already set (the deal is live)
  # - paused: requires a reason so the team knows why
  # - ended: requires a reason; clears follow-up
  # - negotiating: back to the table; clears follow-up
  # Logs a status_change activity on the timeline when the status changes.
  # `actor` may be a SalesUser or an Admin — only a SalesUser is written to
  # sales_user_id; an admin is attributed via the activity's actor_name.
  def transition_to!(new_status, actor: nil, note: nil, signed_on: nil, follow_up_date: nil,
                     follow_up_note: nil)
    target = new_status.to_s
    rep = sales_user_for(actor)

    case target
    when 'paused', 'ended'
      raise TransitionError, 'A reason is required — the team needs to know why' if note.blank?
    end

    if status == target
      updates = {}
      updates[:follow_up_date] = follow_up_date unless follow_up_date.nil?
      updates[:follow_up_note] = follow_up_note unless follow_up_note.nil?
      update!(updates) if updates.any?
      return
    end

    attrs = { status: target }
    attrs[:sales_user_id] = rep.id if rep && sales_user_id.nil?

    case target
    when 'active'
      attrs[:signed_on] = signed_on.presence || self.signed_on || Date.current
      attrs[:follow_up_date] = follow_up_date.nil? ? self.follow_up_date : follow_up_date.presence
      attrs[:follow_up_note] = follow_up_note.nil? ? self.follow_up_note : follow_up_note.presence
    when 'negotiating'
      attrs[:follow_up_date] = follow_up_date.nil? ? self.follow_up_date : follow_up_date.presence
      attrs[:follow_up_note] = follow_up_note.nil? ? self.follow_up_note : follow_up_note.presence
    when 'paused', 'ended'
      attrs[:follow_up_date] = nil
      attrs[:follow_up_note] = note
    end

    update!(attrs)
    activities.create!(
      activity_type: 'status_change',
      sales_user: rep,
      actor_name: actor_name_for(actor),
      occurred_at: Time.current,
      outcome: status,
      notes: note.presence || "Status changed to #{status.humanize}"
    )
  end

  # Find a platform seller matching this partner — by phone (normalized
  # suffix) first, then by exact email.
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

  # Link the partner's storefront seller account.
  def link_seller!(seller, actor: nil)
    update!(seller_id: seller.id)
    activities.create!(
      activity_type: 'registered',
      sales_user: sales_user_for(actor),
      actor_name: actor_name_for(actor),
      occurred_at: Time.current,
      notes: "Linked to seller account #{seller.enterprise_name.presence || seller.fullname}"
    )
  end
end
