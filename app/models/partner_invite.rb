# frozen_string_literal: true

# A join/confirmation invite for a partner, distributor, or partner contact.
#
# invite_kind:
#   new_account      — no platform account yet; accept = set password → seller login
#   existing_account — already a registered seller; accept = confirm partnership
#   contact_confirm  — non-selling partner contact; accept = acknowledge details
#
# The raw token is stored (not digested) so reminder emails can reuse the same
# working link across the invite's 7-day life — single-use via `status`.
class PartnerInvite < ApplicationRecord
  TOKEN_TTL = 7.days

  # Reminder cadence after the initial invite — stage 1 at T+2d (gentle),
  # stage 2 at T+5d (urgency). Industry standard: max 2 reminders.
  REMINDER_SCHEDULE = [2.days, 5.days].freeze

  belongs_to :invitee, polymorphic: true
  belongs_to :seller, optional: true
  belongs_to :invited_by, polymorphic: true, optional: true

  enum :status, {
    pending: 0,
    accepted: 1,
    expired: 2,
    revoked: 3
  }, default: :pending, scopes: false

  enum :invite_kind, {
    new_account: 0,
    existing_account: 1,
    contact_confirm: 2
  }, default: :new_account, scopes: false

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :usable, -> { pending.where(expires_at: Time.current..) }
  scope :due_for_reminder, lambda {
    pending.where(expires_at: Time.current..).where(
      '(reminder_count = 0 AND created_at <= :r1) OR (reminder_count = 1 AND last_reminded_at <= :r2)',
      r1: REMINDER_SCHEDULE[0].ago,
      r2: (REMINDER_SCHEDULE[1] - REMINDER_SCHEDULE[0]).ago
    )
  }
  scope :past_expiry, -> { pending.where(expires_at: ...Time.current) }

  # Mint a new invite. Returns the record with `token` populated.
  def self.issue!(invitee:, email: nil, phone: nil, seller: nil, invited_by: nil, invite_kind: nil)
    create!(
      invitee: invitee,
      seller: seller,
      email: email.presence,
      phone: phone.presence,
      invited_by: invited_by,
      invite_kind: invite_kind.presence || (seller&.persisted? ? 'existing_account' : 'new_account'),
      token: SecureRandom.urlsafe_base64(32),
      expires_at: TOKEN_TTL.from_now
    )
  end

  def self.with_token(raw)
    find_by(token: raw.to_s)
  end

  def usable?
    pending? && expires_at > Time.current
  end

  def join_url
    base = ENV['FRONTEND_URL'].presence || 'https://carboncube-ke.com'
    "#{base}/partner/join?token=#{token}"
  end

  # Which reminder is due next (1 or 2), or nil when none is due.
  def reminder_stage_due
    return nil unless pending? && expires_at > Time.current

    if reminder_count.zero? && created_at <= REMINDER_SCHEDULE[0].ago
      1
    elsif reminder_count == 1 &&
          (last_reminded_at || created_at) <= (REMINDER_SCHEDULE[1] - REMINDER_SCHEDULE[0]).ago
      2
    end
  end

  def mark_reminded!
    update!(reminder_count: reminder_count + 1, last_reminded_at: Time.current)
  end

  def mark_invite_sent!
    update!(invite_sent_at: Time.current)
  end

  def expire!
    update!(status: 'expired') if pending?
  end

  def revoke!
    update!(status: 'revoked', revoked_at: Time.current) if pending?
  end

  # Accept the invite.
  # - new_account: requires password params — sets the shell seller's password
  # - existing_account: requires the authenticated seller to match invite.seller
  # - contact_confirm: no requirements — just acknowledges
  # Returns the seller when one is attached (so the controller can issue a JWT).
  def accept!(password: nil, password_confirmation: nil, acting_seller: nil)
    return false unless usable?

    case invite_kind
    when 'new_account'
      raise ArgumentError, 'Password is required' if password.blank?
      raise ArgumentError, 'No seller account attached to this invite' if seller.nil?

      seller.update!(password: password, password_confirmation: password_confirmation)
    when 'existing_account'
      unless acting_seller && seller_id == acting_seller.id
        raise ArgumentError, 'You must be signed in as the invited account to accept'
      end
    end

    update!(status: 'accepted', accepted_at: Time.current)
    activate_invitee!
    grant_premium_tier!
    sync_storefront_profile!
    create_main_branch!
    seller
  end

  # Re-issue: revoke this invite and mint a fresh token + expiry window.
  def resend!(invited_by: nil)
    revoke!
    self.class.issue!(
      invitee: invitee,
      email: email,
      phone: phone,
      seller: seller,
      invited_by: invited_by || self.invited_by,
      invite_kind: invite_kind
    )
  end

  private

  # Flip the invitee into its post-acceptance state.
  def activate_invitee!
    case invitee
    when Partner
      invitee.transition_to!('active', actor: invited_by) if invitee.negotiating?
    when PartnerDistributor
      invitee.activate!
    end
  end

  # Partner sellers ride on the Premium tier as part of the partnership —
  # granted on acceptance, not invite issue, so the benefit only lands once
  # the account is actually claimed. Effectively permanent (100y, same
  # convention as the seeded Free tier rows).
  def grant_premium_tier!
    return unless seller

    premium = Tier.find_by(name: 'Premium')
    return unless premium

    attrs = { tier: premium, duration_months: 1200, expires_at: 100.years.from_now }
    if seller.seller_tier
      seller.seller_tier.update!(attrs)
    else
      seller.create_seller_tier!(**attrs)
    end
  rescue StandardError => e
    Rails.logger.error "PartnerInvite##{id}: premium tier grant failed — #{e.message}"
  end

  # Same as normal signup — every seller gets a main branch. The shell
  # carries the business's location, so the storefront shows the right
  # pin from day one. Skips when the seller already has branches or no
  # location to pin (Branch requires it).
  def create_main_branch!
    return unless seller
    return if seller.branches.exists?
    return if seller.location.blank?

    seller.branches.create!(
      name: seller.enterprise_name.presence || seller.fullname.presence || 'Main Branch',
      location: seller.location,
      profile_picture: seller.profile_picture,
      phone: seller.phone_number,
      secondary_phone: seller.secondary_phone_number,
      county_id: seller.county_id,
      sub_county_id: seller.sub_county_id,
      is_main_branch: true
    )
  rescue StandardError => e
    Rails.logger.error "PartnerInvite##{id}: main branch creation failed — #{e.message}"
  end

  # The shell seller starts bare — mirror the invitee's public identity so
  # the storefront isn't empty: logo as avatar, about text, website.
  # Also ensures a username and clean slug exist.
  # Only fills blanks — anything the seller set themselves stays.
  def sync_storefront_profile!
    return unless seller

    updates = {}
    updates[:profile_picture] = invitee.try(:logo_url) if seller.profile_picture.blank? && invitee.try(:logo_url).present?
    updates[:description] = invitee.try(:description) if seller.description.blank? && invitee.try(:description).present?
    updates[:website] = invitee.try(:website) if seller.website.blank? && invitee.try(:website).present?
    seller.update!(updates) if updates.any?
    seller.assign_username_and_slug!
  rescue StandardError => e
    Rails.logger.error "PartnerInvite##{id}: storefront profile sync failed — #{e.message}"
  end
end
