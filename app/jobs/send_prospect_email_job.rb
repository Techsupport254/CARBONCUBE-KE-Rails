# frozen_string_literal: true

# Delivers one cold-outreach email to a single OutreachProspect.
# Guarded by status so retries or re-runs never double-send a prospect.
class SendProspectEmailJob < ApplicationJob
  queue_as :broadcast

  retry_on Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError,
           wait: :polynomially_longer, attempts: 2

  def perform(prospect_id, sender_name: nil)
    prospect = OutreachProspect.find_by(id: prospect_id)
    return unless prospect

    # Another worker already sent it (or it was skipped manually) — no-op.
    unless prospect.status == 'pending'
      Rails.logger.info "[SendProspectEmailJob] Prospect #{prospect_id} is #{prospect.status}, skipping"
      return
    end

    unless prospect.email.present? && prospect.email.match?(OutreachProspect::EMAIL_FORMAT)
      prospect.update_columns(status: 'skipped', error: 'missing or invalid email', updated_at: Time.current)
      return
    end

    mail = ProspectMailer.with(
      to: prospect.email,
      business_name: prospect.business_name,
      area: prospect.area,
      category: prospect.category,
      subcategory: prospect.subcategory,
      sender_name: sender_name
    ).cold_outreach
    mail.deliver_now

    prospect.update_columns(status: 'sent', sent_at: Time.current,
                            message_id: mail.message_id, error: nil, updated_at: Time.current)
  rescue StandardError => e
    begin
      prospect&.update_columns(status: 'failed', error: e.message.truncate(500), updated_at: Time.current)
    rescue StandardError
      nil
    end
    raise
  end
end
