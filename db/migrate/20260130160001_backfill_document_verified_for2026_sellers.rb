class BackfillDocumentVerifiedFor2026Sellers < ActiveRecord::Migration[7.1]
  def up
    # Same logic as premium promo: auto-verify documents for 2026 sellers (first half of 2026 cohort)
    count = Seller.where("EXTRACT(YEAR FROM created_at) = ?", 2026).where(document_verified: false).update_all(document_verified: true)
    Rails.logger.info "✅ Backfilled document_verified for #{count} 2026 seller(s)" if count && count > 0
  end

  def down
    # No rollback - we don't unverify documents
  end
end
