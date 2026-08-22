require 'net/http'
require 'uri'
require 'json'

class SendProfileCompletionCampaignJob < ApplicationJob
  queue_as :broadcast

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  PROFILE_FIELDS = %w[enterprise_name description phone_number email profile_picture].freeze

  def perform(dry_run = true, test_email = nil)
    sellers = find_incomplete_sellers

    if test_email.present?
      sample_seller = sellers.first || Seller.where(deleted: false).first
      if sample_seller.nil?
        Rails.logger.warn "[ProfileCompletionCampaign] No sellers found for sample data"
        return
      end

      missing = missing_fields_for(sample_seller)
      completion = completion_percent_for(sample_seller)

      if dry_run
        Rails.logger.info "[ProfileCompletionCampaign] [DRY RUN] Would send to #{test_email}"
      else
        send_email(test_email, sample_seller, missing, completion)
      end
      return
    end

    sent_count = 0
    skipped_count = 0

    sellers.find_each(batch_size: 100) do |seller|
      email = seller.email.to_s.strip.downcase
      if email.blank?
        skipped_count += 1
        next
      end

      dedup_key = "campaign:profile_completion:sent_emails"
      already_sent = RedisConnection.with { |conn| conn.sismember(dedup_key, email) }
      if already_sent
        skipped_count += 1
        next
      end

      missing = missing_fields_for(seller)
      completion = completion_percent_for(seller)

      unless dry_run
        send_email(email, seller, missing, completion)
        RedisConnection.with { |conn| conn.sadd(dedup_key, email) }
      end
      sent_count += 1
    end

    Rails.logger.info "[ProfileCompletionCampaign] Done. Sent: #{sent_count}, Skipped: #{skipped_count}"
  end

  private

  def find_incomplete_sellers
    Seller.where(deleted: false)
          .where.not(email: [nil, ''])
          .where(
            'enterprise_name IS NULL OR enterprise_name = ? ' \
            'OR description IS NULL OR description = ? ' \
            'OR phone_number IS NULL OR phone_number = ? ' \
            'OR profile_picture IS NULL OR profile_picture = ? ' \
            'OR location IS NULL OR location = ?',
            '', '', '', '', ''
          )
          .order(created_at: :desc)
  end

  def missing_fields_for(seller)
    fields = []
    fields << 'enterprise_name' if seller.enterprise_name.blank?
    fields << 'description' if seller.description.blank?
    fields << 'phone_number' if seller.phone_number.blank?
    fields << 'email' if seller.email.blank?
    fields << 'profile_picture' if seller.profile_picture.blank?
    fields << 'location' if seller.location.blank?
    fields
  end

  def completion_percent_for(seller)
    total = PROFILE_FIELDS.size + 1 # +1 for location
    present = 0
    present += 1 if seller.enterprise_name.present?
    present += 1 if seller.description.present?
    present += 1 if seller.phone_number.present?
    present += 1 if seller.email.present?
    present += 1 if seller.profile_picture.present?
    present += 1 if seller.location.present?
    (present.to_f / total * 100).round
  end

  def send_email(email, seller, missing_fields, completion_percent)
    if email.blank?
      Rails.logger.warn "[ProfileCompletionCampaign] Skipping send_email for seller #{seller.id} - email is blank"
      return
    end

    unless email.include?('@') && email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      Rails.logger.warn "[ProfileCompletionCampaign] Skipping send_email for seller #{seller.id} - invalid email format: #{email}"
      return
    end

    call_center_url = ENV['CALL_CENTER_API_URL'] || 'http://localhost:3000'
    uri = URI.parse("#{call_center_url}/api/send-profile-completion")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    token = ENV['ADMIN_API_TOKEN'] || ENV['INTERNAL_API_KEY']
    raise "ADMIN_API_TOKEN or INTERNAL_API_KEY must be set" if token.blank?

    request['Authorization'] = "Bearer #{token}"

    payload = {
      to: email,
      sellerName: seller.fullname || 'Partner',
      enterpriseName: seller.enterprise_name,
      missingFields: missing_fields,
      profilePictureUrl: seller.profile_picture,
      profileCompletionPercent: completion_percent
    }

    request.body = payload.to_json

    response = http.request(request)

    unless response.code.to_i == 200
      raise "Profile completion email API returned status #{response.code}: #{response.body}"
    end
  end
end
