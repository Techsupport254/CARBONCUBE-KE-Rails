# frozen_string_literal: true

class DocumentComplianceCheckJob < ApplicationJob
  queue_as :low

  def perform
    Seller
      .joins(:seller_documents)
      .where(
        "seller_documents.document_verified = ? OR seller_documents.document_expiry_date < ?",
        false,
        Date.current
      )
      .distinct
      .find_each do |seller|
        SendDocumentComplianceReminderJob.perform_later(
          seller.id,
          reminder_type: 'general',
          channel: 'all'
        )
      end
  end
end
