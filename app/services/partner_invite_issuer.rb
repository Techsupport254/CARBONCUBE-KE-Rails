# frozen_string_literal: true

# Issues PartnerInvite records for a partner, distributor, or contact.
#
# Decides the invite kind and, for selling invitees without a seller account,
# provisions a shell Seller the invitee activates by setting a password via
# the join link. The shell is marked provider='partner_invite' so OAuth-style
# validations are skipped until they complete their profile after joining.
class PartnerInviteIssuer
  class Error < StandardError; end

  def self.call(invitee, actor:, email: nil, phone: nil)
    new(invitee, actor: actor, email: email, phone: phone).call
  end

  # Provision a shell Seller for a selling invitee (used when staff explicitly
  # ask to create the partner's account, e.g. at partner-create time).
  def self.provision_shell_seller(invitee)
    email = invitee.try(:email)
    raise Error, 'An email is required to create the account — add one to the record first' if email.blank?

    Seller.create!(
      fullname: invitee.try(:contact_person).presence || invitee.try(:name) || 'Partner',
      enterprise_name: invitee.try(:name) || 'Partner',
      email: email,
      phone_number: invitee.try(:phone),
      location: invitee.try(:location),
      provider: 'partner_invite',
      password: SecureRandom.alphanumeric(32)
    )
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.join(', ')
  end

  def initialize(invitee, actor:, email: nil, phone: nil)
    @invitee = invitee
    @actor = actor
    @email = email
    @phone = phone
  end

  def call
    prepare_seller!

    PartnerInvite.issue!(
      invitee: @invitee,
      seller: @seller,
      email: @email.presence || invitee_email,
      phone: @phone.presence || invitee_phone,
      invited_by: @actor,
      invite_kind: invite_kind
    )
  end

  private

  # Work out the seller situation:
  # - linked seller already → use it
  # - auto-match an existing platform seller → link + use it
  # - selling invitee with no match → provision a shell seller
  # - contact / non-selling invitee → no seller
  def prepare_seller!
    @seller = @invitee.respond_to?(:seller) ? @invitee.seller : nil
    return @seller if @seller.present?
    return nil unless @invitee.respond_to?(:matching_seller)

    if @invitee.is_a?(PartnerContact)
      return nil
    end

    matched = @invitee.matching_seller
    if matched
      link_seller(matched)
      @seller = matched
    elsif selling_invitee?
      @seller = create_shell_seller
      link_seller(@seller)
    end
  end

  def selling_invitee?
    case @invitee
    when Partner then @invitee.sells_on_platform?
    when PartnerDistributor then true
    else false
    end
  end

  def create_shell_seller
    self.class.provision_shell_seller(@invitee)
  end

  def link_seller(seller)
    if @invitee.respond_to?(:link_seller!)
      @invitee.link_seller!(seller)
    else
      @invitee.update!(seller_id: seller.id)
    end
  end

  def invite_kind
    return 'contact_confirm' if @invitee.is_a?(PartnerContact)

    if @seller&.persisted? && @seller.provider == 'partner_invite'
      'new_account'
    elsif @seller&.persisted?
      'existing_account'
    else
      'contact_confirm'
    end
  end

  def invitee_email
    @email.presence || @invitee.try(:email) || @seller&.email
  end

  def invitee_phone
    @phone.presence || @invitee.try(:phone) || @seller&.phone_number
  end
end
