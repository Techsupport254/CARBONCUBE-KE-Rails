# frozen_string_literal: true

class SalesBrand < ApplicationRecord
  belongs_to :sales_user, optional: true
  belongs_to :seller, optional: true
  has_many :activities, -> { recent_first },
           class_name: 'SalesBrandActivity',
           inverse_of: :sales_brand,
           dependent: :destroy

  # Pipeline status for sales outreach on directory brands
  enum :status, {
    not_contacted: 0,
    contacted: 1,
    follow_up: 2,
    interested: 3,
    onboarded: 4,
    not_interested: 5,
    hesitant: 6
  }, default: :not_contacted, scopes: false

  # directory = seeded Brand Kenya master list; field = shop added by a rep
  # while out in the field
  enum :source, {
    directory: 0,
    field: 1
  }, default: :directory, scopes: false

  validates :name, presence: true

  before_validation :normalize_phone_number

  # Normalize Kenyan phone numbers the same way Seller/Buyer do, so suffix
  # matching against call logs and seller signups works.
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

  scope :search, lambda { |query|
    return all if query.blank?

    term = "%#{query.to_s.downcase}%"
    where(
      'LOWER(name) LIKE :term OR LOWER(location) LIKE :term OR ' \
      'LOWER(scope) LIKE :term OR LOWER(category) LIKE :term OR ' \
      'phone LIKE :term OR LOWER(email) LIKE :term',
      term: term
    )
  }

  # Record a touchpoint (call, visit, whatsapp, …) and roll its effects up to
  # the brand's current-state fields.
  def record_activity!(type:, user:, occurred_at: nil, notes: nil, outcome: nil, follow_up_date: nil,
                       latitude: nil, longitude: nil)
    activity = activities.create!(
      activity_type: type,
      sales_user: user,
      occurred_at: occurred_at.presence || Time.current,
      notes: notes,
      outcome: outcome,
      follow_up_date: follow_up_date,
      latitude: latitude,
      longitude: longitude
    )

    updates = {}
    # The rep who adds the first activity becomes the owner when unassigned
    updates[:sales_user_id] = user.id if sales_user_id.nil? && user
    if SalesBrandActivity::CONTACT_TYPES.include?(activity.activity_type)
      updates[:last_contacted_at] = activity.occurred_at
      updates[:status] = 'contacted' if not_contacted?
      # A hesitant/failed/interested attempt shouldn't silently lose that fact
      if %w[not_contacted contacted].include?(updates[:status] || status)
        updates[:status] = 'hesitant' if activity.outcome == 'hesitant'
        updates[:status] = 'not_interested' if activity.outcome == 'not_interested'
      end
      updates[:status] = 'interested' if activity.outcome == 'interested' &&
                                         %w[not_contacted contacted follow_up hesitant].include?(updates[:status] || status)
    end
    if activity.follow_up_date.present?
      updates[:follow_up_date] = activity.follow_up_date
      updates[:follow_up_note] = activity.notes if activity.notes.present?
      updates[:status] = 'follow_up' if %w[not_contacted contacted hesitant].include?(updates[:status] || status)
    elsif SalesBrandActivity::CONTACT_TYPES.include?(activity.activity_type) &&
          self.follow_up_date.present?
      # Any logged contact means the follow-up was actioned (even early) —
      # don't leave it lingering in the queue. A new date replaces it instead.
      updates[:follow_up_date] = nil
      updates[:follow_up_note] = nil
      updates[:status] = 'contacted' if (updates[:status] || status) == 'follow_up'
    end
    update!(updates) if updates.any?

    activity
  end

  # Raised when a status transition is missing its required data
  class TransitionError < StandardError; end

  # Apply a status change with its per-status rules:
  # - not_contacted: clears any scheduled follow-up (fresh start)
  # - contacted: stamps last_contacted_at; a provided date promotes it to follow_up
  # - follow_up: requires a date (they asked us to come back on a day)
  # - hesitant / not_interested: require a reason; clear any follow-up
  # - interested: keeps optional follow-up
  # - onboarded: tries to link an existing platform seller by phone; clears follow-up
  # Logs a status_change activity on the timeline when the status changes.
  # nil follow_up_* args mean "leave as-is"; blank means "clear".
  def transition_to!(new_status, actor: nil, follow_up_date: nil, follow_up_note: nil)
    target = new_status.to_s
    date = follow_up_date.nil? ? self.follow_up_date : follow_up_date.presence
    note = follow_up_note.nil? ? self.follow_up_note : follow_up_note.presence

    case target
    when 'follow_up'
      raise TransitionError, 'A follow-up date is required — they asked you to come back on a specific day' if date.blank?
    when 'hesitant', 'not_interested'
      raise TransitionError, 'A reason is required — the next rep needs to know why' if note.blank?
    end

    # Status unchanged — just apply any follow-up fields the caller sent.
    if status == target
      updates = {}
      updates[:follow_up_date] = date unless follow_up_date.nil?
      updates[:follow_up_note] = note unless follow_up_note.nil?
      update!(updates) if updates.any?
      return
    end

    attrs = { status: target }
    # The rep changing the pipeline becomes the owner when unassigned
    attrs[:sales_user_id] = actor.id if actor && sales_user_id.nil?
    # Any status other than not_contacted implies contact has happened — keep
    # the "reached" roll-up accurate even when no activity was logged.
    attrs[:last_contacted_at] ||= Time.current if target != 'not_contacted'

    case target
    when 'not_contacted'
      attrs[:follow_up_date] = nil
      attrs[:follow_up_note] = nil
    when 'contacted'
      if date.present?
        attrs[:status] = 'follow_up'
        attrs[:follow_up_date] = date
        attrs[:follow_up_note] = note
      end
    when 'follow_up', 'interested'
      attrs[:follow_up_date] = date
      attrs[:follow_up_note] = note
    when 'hesitant', 'not_interested'
      attrs[:follow_up_date] = nil
      attrs[:follow_up_note] = note
    when 'onboarded'
      attrs[:follow_up_date] = nil
      matched = matching_seller
      if matched && seller_id.blank?
        attrs[:seller_id] = matched.id
        attrs[:registered_at] ||= matched.created_at
      end
    end

    update!(attrs)
    activities.create!(
      activity_type: 'status_change',
      sales_user: actor,
      occurred_at: Time.current,
      outcome: status,
      notes: "Status changed to #{status.humanize}"
    )
  end

  # Link a platform seller account — marks the brand as registered/onboarded.
  def register!(seller_id)
    update!(
      seller_id: seller_id,
      registered_at: Time.current,
      status: 'onboarded',
      follow_up_date: nil,
      follow_up_note: nil,
      last_contacted_at: last_contacted_at || Time.current
    )
  end

  # Find a platform seller whose phone matches this brand's (normalized).
  def matching_seller
    return nil if phone.blank?

    suffix = phone.gsub(/\D/, '')[-9..]
    return nil if suffix.blank? || suffix.length < 9

    Seller.find_by('phone_number LIKE ?', "%#{suffix}")
  end
end
