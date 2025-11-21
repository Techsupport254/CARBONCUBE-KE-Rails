class VerifyAll2025SellersDocuments < ActiveRecord::Migration[7.1]
  def up
    # Update all 2025 sellers to have document_verified = true
    # Sales team confirms all 2025 registrations physically, so all should be verified
    # This includes sellers without document_url (which the previous migration didn't cover)
    sellers_updated = execute(<<-SQL.squish
      UPDATE sellers
      SET document_verified = true
      WHERE EXTRACT(YEAR FROM created_at) = 2025
        AND document_verified = false
    SQL
    )
    
    Rails.logger.info "✅ Updated #{sellers_updated.cmd_tuples} 2025 sellers with document verification (sales team confirmed physically)"
  end

  def down
    # Note: We don't reverse this as it's a data fix based on business logic
    # If needed, you can manually unverify documents
  end
end

